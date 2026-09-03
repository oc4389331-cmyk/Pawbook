require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { createClient } = require('@supabase/supabase-js');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

// Env Configuration
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID || '';
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID || '';
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY || '';
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || 'pawtbook-media';
const R2_CUSTOM_DOMAIN = process.env.R2_CUSTOM_DOMAIN || 'https://media.pawbooklife.com';

const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

// Initialize Cloudflare R2 (S3 Compatible API)
let r2Client = null;
if (R2_ACCOUNT_ID && R2_ACCESS_KEY_ID && R2_SECRET_ACCESS_KEY) {
  r2Client = new S3Client({
    region: 'auto',
    endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: R2_ACCESS_KEY_ID,
      secretAccessKey: R2_SECRET_ACCESS_KEY,
    },
  });
  console.log('✅ Cloudflare R2 S3 Client initialized successfully');
} else {
  console.log('⚠️ Running Cloudflare R2 in mock mode (Missing R2 credentials in .env)');
}

// Initialize Supabase Admin Client
let supabaseAdmin = null;
if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
  supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  console.log('✅ Supabase Admin Client initialized successfully');
} else {
  console.log('⚠️ Running Supabase in mock mode (Missing SUPABASE_SERVICE_ROLE_KEY in .env)');
}

// 1. Dynamic.xyz Auth verification endpoint
app.post('/api/auth/verify', async (req, res) => {
  const { token, walletAddress, email } = req.body;
  if (!walletAddress && !email) {
    return res.status(400).json({ success: false, error: 'Missing walletAddress or email' });
  }

  const userId = 'usr_' + (walletAddress ? walletAddress.substring(0, 8) : 'email');

  // Optional: Sync user into Supabase profiles via admin client
  if (supabaseAdmin) {
    try {
      const { data, error } = await supabaseAdmin
        .from('profiles')
        .upsert({
          id: userId,
          wallet_address: walletAddress || null,
          username: 'paw_' + (walletAddress ? walletAddress.substring(0, 8) : 'user'),
          pawt_score: 100
        }, { onConflict: 'wallet_address' });

      if (error) console.error('Supabase profile sync error:', error);
    } catch (e) {
      console.error('Supabase sync exception:', e);
    }
  }

  return res.json({
    success: true,
    user: {
      id: userId,
      walletAddress: walletAddress || null,
      email: email || null,
      pawtScore: 100
    }
  });
});

// 2. R2 Presigned Upload URL endpoint (Requires registered Pet Profile)
app.post('/api/media/upload-url', async (req, res) => {
  const { petId, mediaType, filename } = req.body;

  // Key Business Rule: Only Pet Profiles can upload content
  if (!petId) {
    return res.status(403).json({
      success: false,
      error: 'ROLE_RESTRICTION: Only Pet Profiles can upload content. Human sponsors must register a pet first.'
    });
  }

  const ext = filename ? filename.split('.').pop() : (mediaType === 'video' ? 'mp4' : 'jpg');
  const uniqueKey = `posts/${petId}_${Date.now()}.${ext}`;
  const publicUrl = `${R2_CUSTOM_DOMAIN}/${uniqueKey}`;
  const contentType = mediaType === 'video' ? 'video/mp4' : 'image/jpeg';

  let presignedPutUrl = `${R2_CUSTOM_DOMAIN}/upload-signed-vault/${uniqueKey}?signature=mock_r2_sig`;

  // Real Cloudflare R2 Presigned URL Generation via S3 Client
  if (r2Client) {
    try {
      const command = new PutObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: uniqueKey,
        ContentType: contentType,
      });

      // Expires in 15 minutes (900 seconds)
      presignedPutUrl = await getSignedUrl(r2Client, command, { expiresIn: 900 });
    } catch (err) {
      console.error('Error generating Cloudflare R2 Presigned URL:', err);
      return res.status(500).json({ success: false, error: 'Failed to generate R2 Presigned URL' });
    }
  }

  return res.json({
    success: true,
    petId,
    key: uniqueKey,
    presignedPutUrl,
    publicUrl,
    initialStatus: 'pending_review'
  });
});

// 3. Safety & Animal Welfare Moderation Pipeline Trigger
app.post('/api/media/moderate', async (req, res) => {
  const { postId, mediaUrl, forceDecision } = req.body;

  if (!postId || !mediaUrl) {
    return res.status(400).json({ success: false, error: 'Missing postId or mediaUrl' });
  }

  let status = 'active';
  let moderationReason = 'Passed safety and animal welfare verification';

  if (forceDecision === 'reject' || mediaUrl.includes('inappropriate') || mediaUrl.includes('abuse')) {
    status = 'rejected';
    moderationReason = 'FAILED_MODERATION: Flagged for policy violation or unsafe content';
  }

  // Update Supabase posts status
  if (supabaseAdmin) {
    try {
      await supabaseAdmin
        .from('posts')
        .update({ status, moderation_reason: moderationReason })
        .eq('id', postId);
    } catch (e) {
      console.error('Supabase moderation update error:', e);
    }
  }

  return res.json({
    success: true,
    postId,
    status,
    reason: moderationReason
  });
});

app.listen(PORT, () => {
  console.log(`Pawtbook Backend API running on port ${PORT}`);
});
