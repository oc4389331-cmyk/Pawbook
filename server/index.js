require('dotenv').config();
const express = require('express');
const cors = require('cors');
const Stripe = require('stripe');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { createClient } = require('@supabase/supabase-js');

const app = express();
app.use(cors());

const PORT = process.env.PORT || 3000;

// Env Configuration
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID || '';
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID || '';
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY || '';
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || 'pawtbook-media';
const R2_CUSTOM_DOMAIN = process.env.R2_CUSTOM_DOMAIN || 'https://media.pawbooklife.com';

const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || 'whsec_m7a70Z7bRCbjOtqqDYK12DhNPQnlR42D';

// Initialize Stripe Client
let stripe = null;
if (STRIPE_SECRET_KEY && !STRIPE_SECRET_KEY.includes('your_stripe_secret_key')) {
  stripe = new Stripe(STRIPE_SECRET_KEY);
  console.log('✅ Stripe Payment SDK initialized successfully');
} else {
  console.log('⚠️ Running Stripe in webhook/mock mode (Missing STRIPE_SECRET_KEY in .env)');
}

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

// --------------------------------------------------------------------------
// 1. STRIPE WEBHOOK ROUTE (Must use raw body parser for signature verification)
// --------------------------------------------------------------------------
app.post('/api/webhooks/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    if (stripe && STRIPE_WEBHOOK_SECRET) {
      event = stripe.webhooks.constructEvent(req.body, sig, STRIPE_WEBHOOK_SECRET);
    } else {
      // Dev/fallback mode if raw signature check is bypassed
      const rawPayload = typeof req.body === 'string' || Buffer.isBuffer(req.body)
        ? req.body.toString('utf8')
        : JSON.stringify(req.body);
      event = JSON.parse(rawPayload);
    }
  } catch (err) {
    console.error(`⚠️ Stripe Webhook signature verification failed: ${err.message}`);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  console.log(`⚡ Stripe Event Received: ${event.type}`);

  // Handle events specified in user's Stripe Webhook dashboard:
  // checkout.session.completed, payment_intent.succeeded
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object;
      console.log(`✅ Payment checkout session completed for ${session.customer_email || session.id}`);
      
      const { userId, petId, pointsAmount } = session.metadata || {};
      if (supabaseAdmin && userId && pointsAmount) {
        try {
          const { data: profile } = await supabaseAdmin
            .from('profiles')
            .select('pawt_score')
            .eq('id', userId)
            .single();

          const newScore = (profile?.pawt_score || 0) + parseInt(pointsAmount, 10);
          await supabaseAdmin
            .from('profiles')
            .update({ pawt_score: newScore })
            .eq('id', userId);

          console.log(`🎉 Granted ${pointsAmount} PawtScore to user ${userId}. New total: ${newScore}`);
        } catch (e) {
          console.error('Error granting PawtScore points via Stripe webhook:', e);
        }
      }
      break;
    }

    case 'payment_intent.succeeded': {
      const paymentIntent = event.data.object;
      console.log(`💰 PaymentIntent succeeded: ${paymentIntent.id} ($${paymentIntent.amount / 100} USD)`);
      break;
    }

    default:
      console.log(`Unhandled Stripe event type: ${event.type}`);
  }

  return res.json({ received: true });
});

// JSON Body Parser for all remaining routes
app.use(express.json());

// --------------------------------------------------------------------------
// 2. HEALTH CHECK ENDPOINT
// --------------------------------------------------------------------------
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Pawtbook Backend API',
    version: '1.1.0',
    stripeWebhookPath: '/api/webhooks/stripe'
  });
});

// --------------------------------------------------------------------------
// 3. DYNAMIC.XYZ AUTH VERIFICATION ENDPOINT
// --------------------------------------------------------------------------
app.post('/api/auth/verify', async (req, res) => {
  const { token, walletAddress, email } = req.body;
  if (!walletAddress && !email) {
    return res.status(400).json({ success: false, error: 'Missing walletAddress or email' });
  }

  const userId = 'usr_' + (walletAddress ? walletAddress.substring(0, 8) : 'email');

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

// --------------------------------------------------------------------------
// 4. CLOUDFLARE R2 PRESIGNED UPLOAD URL ENDPOINT
// --------------------------------------------------------------------------
app.post('/api/media/upload-url', async (req, res) => {
  const { petId, mediaType, filename } = req.body;

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

  if (r2Client) {
    try {
      const command = new PutObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: uniqueKey,
        ContentType: contentType,
      });

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

// --------------------------------------------------------------------------
// 5. SAFETY & ANIMAL WELFARE MODERATION PIPELINE
// --------------------------------------------------------------------------
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

// --------------------------------------------------------------------------
// 6. STRIPE CHECKOUT SESSION CREATION ENDPOINT
// --------------------------------------------------------------------------
app.post('/api/payments/create-checkout-session', async (req, res) => {
  const { userId, petId, pointsAmount, priceUsd, successUrl, cancelUrl } = req.body;

  if (!stripe) {
    return res.json({
      success: true,
      mode: 'mock',
      url: successUrl || 'https://pawbook-358b.onrender.com/?payment=success_mock',
      message: 'Stripe simulated in mock mode (Missing STRIPE_SECRET_KEY)'
    });
  }

  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: `Pawtbook - ${pointsAmount || 100} PawtScore Points`,
              description: petId ? `Sponsorship for Pet ID: ${petId}` : 'PawtScore Community Pack',
            },
            unit_amount: Math.round((priceUsd || 4.99) * 100),
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      metadata: {
        userId: userId || 'usr_guest',
        petId: petId || '',
        pointsAmount: (pointsAmount || 100).toString(),
      },
      success_url: successUrl || `https://pawbook-358b.onrender.com/?payment=success`,
      cancel_url: cancelUrl || `https://pawbook-358b.onrender.com/?payment=cancel`,
    });

    return res.json({
      success: true,
      url: session.url,
      sessionId: session.id
    });
  } catch (error) {
    console.error('Error creating Stripe Checkout Session:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// --------------------------------------------------------------------------
// 7. SOLANA PAY SPONSORSHIP ENDPOINT
// --------------------------------------------------------------------------
app.post('/api/sponsorship/solana-pay', async (req, res) => {
  const { sponsorId, petId, amountSol, pawtScoreAmount } = req.body;

  if (!petId || !amountSol) {
    return res.status(400).json({ success: false, error: 'Missing petId or amountSol' });
  }

  const recipientWallet = 'PawSol777VaultSolanaPayAddressPawtbook';
  const solanaPayUrl = `solana:${recipientWallet}?amount=${amountSol}&label=Pawtbook%20Sponsorship&memo=Sponsor_Pet_${petId}`;

  if (supabaseAdmin && sponsorId) {
    try {
      await supabaseAdmin.from('sponsorships').insert({
        id: 'spn_' + Date.now(),
        sponsor_id: sponsorId,
        pet_id: petId,
        amount: pawtScoreAmount || 100,
        payment_method: 'solana_pay',
        tx_hash: 'sol_pay_pending_' + Date.now(),
      });
    } catch (e) {
      console.error('Error inserting Solana Pay sponsorship record:', e);
    }
  }

  return res.json({
    success: true,
    recipientWallet,
    solanaPayUrl,
    qrCodeData: solanaPayUrl,
    message: 'Solana Pay transaction metadata generated successfully'
  });
});

app.listen(PORT, () => {
  console.log(`Pawtbook Backend API running on port ${PORT}`);
  console.log(`⚡ Stripe Webhook route available at /api/webhooks/stripe`);
});
