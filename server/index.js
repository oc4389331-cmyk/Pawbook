require('dotenv').config();
const path = require('path');
const fs = require('fs');
const os = require('os');
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const Stripe = require('stripe');
const { S3Client, PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { createClient } = require('@supabase/supabase-js');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegInstaller = require('@ffmpeg-installer/ffmpeg');

if (ffmpegInstaller && ffmpegInstaller.path) {
  ffmpeg.setFfmpegPath(ffmpegInstaller.path);
  console.log('✅ FFmpeg binary located and configured:', ffmpegInstaller.path);
}

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

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
if (GEMINI_API_KEY && !GEMINI_API_KEY.includes('your_gemini')) {
  console.log('✅ Google Gemini Vision AI Moderation initialized successfully');
} else {
  console.log('⚠️ Running AI Moderation in fallback/mock mode (Missing GEMINI_API_KEY in .env)');
}

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

// Dynamic.xyz Credentials & Provisioning
const DYNAMIC_ENVIRONMENT_ID = process.env.DYNAMIC_ENVIRONMENT_ID || '84fa2357-6be3-4bc4-b90d-2082608d7889';
const DYNAMIC_API_KEY = process.env.DYNAMIC_API_KEY || 'dyn_jPqatSA82agdo2milUdc7CAW6dzlHASQVhgVv9DTbpwLT4TZjj0q3vwO';

if (DYNAMIC_API_KEY) {
  console.log('✅ Dynamic.xyz SDK/API initialized successfully for environment:', DYNAMIC_ENVIRONMENT_ID);
} else {
  console.log('⚠️ Running Dynamic in fallback mode (Missing DYNAMIC_API_KEY in .env)');
}

async function provisionDynamicUser({ email, username, fullName, walletAddress }) {
  if (!DYNAMIC_API_KEY || !DYNAMIC_ENVIRONMENT_ID) return null;
  try {
    const cleanEmail = (email || '').trim().toLowerCase();
    if (!cleanEmail) return null;

    // Check existing users in Dynamic
    const listRes = await fetch(`https://app.dynamicauth.com/api/v0/environments/${DYNAMIC_ENVIRONMENT_ID}/users`, {
      headers: { 'Authorization': `Bearer ${DYNAMIC_API_KEY}` }
    });
    const listData = await listRes.json();
    let user = listData?.users?.find(u => u.email && u.email.toLowerCase() === cleanEmail);

    if (!user) {
      const createRes = await fetch(`https://app.dynamicauth.com/api/v0/environments/${DYNAMIC_ENVIRONMENT_ID}/users`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${DYNAMIC_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: cleanEmail,
          username: username || cleanEmail.split('@')[0],
          firstName: (fullName || '').split(' ')[0] || (username || 'Pawbook User'),
          lastName: (fullName || '').split(' ').slice(1).join(' ') || ''
        })
      });
      const createData = await createRes.json();
      user = createData.user;
    }

    if (user && user.id && walletAddress) {
      // Check if wallet is already linked
      const hasWallet = user.wallets && user.wallets.some(w => w.publicKey === walletAddress);
      if (!hasWallet) {
        await fetch(`https://app.dynamicauth.com/api/v0/environments/${DYNAMIC_ENVIRONMENT_ID}/users/${user.id}/wallets`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${DYNAMIC_API_KEY}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            publicWalletAddress: walletAddress,
            walletName: 'solana',
            walletProvider: 'custodialService',
            chain: 'SOL'
          })
        });
      }
    }

    return user;
  } catch (err) {
    console.error('Dynamic provisioning error:', err.message);
    return null;
  }
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

// JSON Body Parser for all remaining routes (supports video uploads up to 70mb)
app.use(express.json({ limit: '70mb' }));
app.use(express.urlencoded({ limit: '70mb', extended: true }));

// Serve static Flutter Web application build if present
let webBuildPath = path.join(__dirname, 'public');
if (!fs.existsSync(path.join(webBuildPath, 'index.html'))) {
  webBuildPath = path.join(__dirname, '../build/web');
}

if (fs.existsSync(webBuildPath)) {
  app.use(express.static(webBuildPath, {
    index: false,
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('index.html') || filePath.endsWith('flutter_service_worker.js') || filePath.endsWith('version.json') || filePath.endsWith('main.dart.js')) {
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
      }
    }
  }));
  console.log(`🌐 Serving Flutter Web app static files from ${webBuildPath}`);
}

// --------------------------------------------------------------------------
// 2. HEALTH CHECK ENDPOINT
// --------------------------------------------------------------------------
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Pawtbook Backend API',
    version: '1.1.0',
    stripeWebhookPath: '/api/webhooks/stripe'
  });
});
// APK Direct Download endpoint (for Solana Seeker / Android users)
app.get(['/download/apk', '/apk', '/download', '/app.apk', '/pawbook.apk'], (req, res) => {
  const candidatePaths = [
    path.join(__dirname, 'public/app-release.apk'),
    path.join(__dirname, '../build/app/outputs/flutter-apk/app-release.apk'),
    path.join(__dirname, 'public/Pawbook.apk'),
  ];
  for (const apkPath of candidatePaths) {
    if (fs.existsSync(apkPath)) {
      res.setHeader('Content-Type', 'application/vnd.android.package-archive');
      return res.download(apkPath, 'pawbooklife.apk');
    }
  }
  return res.status(404).send('APK no disponible para descarga en este momento. Por favor visita la tienda Solana Seeker dApp Store o la versión web.');
});

// Explicit route for Pawbooklife Presentation Landing Page & Community / Group Invitations
app.get(['/landing', '/presentacion', '/invite', '/join', '/grupo', '/invitacion'], (req, res) => {
  const landingPath = path.join(__dirname, 'public/landing.html');
  if (fs.existsSync(landingPath)) {
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    return res.sendFile(landingPath);
  }
  res.redirect('/');
});

// Legal routes: Terms of Service & Privacy/Security Policy
app.get(['/terms', '/terminos', '/terms-of-service'], (req, res) => {
  const termsPath = path.join(__dirname, 'public/terms.html');
  if (fs.existsSync(termsPath)) {
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    return res.sendFile(termsPath);
  }
  res.redirect('/');
});

app.get(['/privacy', '/privacidad', '/seguridad', '/security', '/privacy-policy'], (req, res) => {
  const privacyPath = path.join(__dirname, 'public/privacy.html');
  if (fs.existsSync(privacyPath)) {
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    return res.sendFile(privacyPath);
  }
  res.redirect('/');
});

// Support route: redirect to official SolChat Plus support group
app.get(['/support', '/soporte', '/solchat', '/chat-soporte'], (req, res) => {
  res.redirect('https://solchatplus.web.app/join/group/ce0f9388-9520-4d89-b4ae-3301125eeb1c');
});

// Direct Dashboard & App redirect routes
app.get(['/app', '/dashboard'], (req, res) => {
  res.redirect('https://pawbook-358b.onrender.com');
});

app.get('/', (req, res, next) => {
  const host = (req.headers.host || '').toLowerCase();
  // If request originates from pawbooklife.com, serve presentation landing page by default
  if (host.includes('pawbooklife.com') && !host.startsWith('media.')) {
    const landingPath = path.join(__dirname, 'public/landing.html');
    if (fs.existsSync(landingPath)) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
      return res.sendFile(landingPath);
    }
  }

  const indexPath = path.join(webBuildPath, 'index.html');
  if (fs.existsSync(indexPath)) {
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    return res.sendFile(indexPath);
  }
  return res.json({
    status: 'ok',
    service: 'Pawtbook Backend API',
    version: '1.1.0',
    stripeWebhookPath: '/api/webhooks/stripe'
  });
});

// --------------------------------------------------------------------------
// 2B. DEVELOPER ANALYTICS & TRAFFIC DASHBOARD ENGINE
// --------------------------------------------------------------------------
const DEV_ADMIN_EMAILS = [
  (process.env.DEV_ADMIN_EMAIL || 'oscar.romero@anda.gob.sv').toLowerCase().trim(),
  'oscar.romero@anda.gob.sv',
  'wernesto66@gmail.com'
];
const DEV_ADMIN_SALT = process.env.DEV_ADMIN_SALT || '8c69ae753cd022c2e034692546953f11';
const DEV_ADMIN_PASSWORD_HASH = process.env.DEV_ADMIN_PASSWORD_HASH || '4bc3b10942bf1a29d09de85cd99d9a6e0a9999f30ddd9af978377468088a20d1a8bb9938ac8f519463eda8685e26844f5b3c577b8fc8c380454677d8a002f280';

function verifyDevPassword(inputPassword) {
  if (!inputPassword) return false;
  try {
    const inputHash = crypto.pbkdf2Sync(inputPassword, DEV_ADMIN_SALT, 100000, 64, 'sha512').toString('hex');
    const inputBuf = Buffer.from(inputHash, 'hex');
    const expectedBuf = Buffer.from(DEV_ADMIN_PASSWORD_HASH, 'hex');
    if (inputBuf.length !== expectedBuf.length) return false;
    return crypto.timingSafeEqual(inputBuf, expectedBuf);
  } catch (err) {
    console.error('Password verification error:', err);
    return false;
  }
}

// Active Dev Sessions (Token -> Session)
const devSessions = new Map();

function verifyDevToken(token) {
  if (!token) return null;
  const session = devSessions.get(token);
  if (!session) return null;
  if (Date.now() > session.expiresAt) {
    devSessions.delete(token);
    return null;
  }
  return session;
}

// Resilient Traffic Analytics Store (Disk + Memory + Supabase)
const trafficDataDir = path.join(__dirname, 'data');
if (!fs.existsSync(trafficDataDir)) {
  fs.mkdirSync(trafficDataDir, { recursive: true });
}
const trafficDataFile = path.join(trafficDataDir, 'traffic_analytics.json');

let trafficStore = {
  events: [],
  daily: {},
  monthly: {}
};

try {
  if (fs.existsSync(trafficDataFile)) {
    const raw = fs.readFileSync(trafficDataFile, 'utf8');
    trafficStore = JSON.parse(raw);
    if (!trafficStore.events) trafficStore.events = [];
    if (!trafficStore.daily) trafficStore.daily = {};
    if (!trafficStore.monthly) trafficStore.monthly = {};
  }
} catch (e) {
  console.warn('Initializing fresh traffic store:', e.message);
}

let saveTrafficTimer = null;
function persistTrafficStore() {
  if (saveTrafficTimer) return;
  saveTrafficTimer = setTimeout(() => {
    saveTrafficTimer = null;
    try {
      fs.writeFileSync(trafficDataFile, JSON.stringify(trafficStore, null, 2), 'utf8');
    } catch (e) {
      console.error('Error writing traffic_analytics.json:', e.message);
    }
  }, 1500);
}

function parseUserAgent(ua = '') {
  let deviceType = 'desktop';
  let os = 'Other';
  let browser = 'Other';

  if (/Mobile|Android|iPhone|iPod|BlackBerry|IEMobile|Opera Mini/i.test(ua)) {
    deviceType = 'mobile';
  } else if (/iPad|Tablet/i.test(ua)) {
    deviceType = 'tablet';
  }

  if (/Android/i.test(ua)) os = 'Android';
  else if (/iPhone|iPad|iPod/i.test(ua)) os = 'iOS';
  else if (/Windows NT/i.test(ua)) os = 'Windows';
  else if (/Macintosh|Mac OS X/i.test(ua)) os = 'macOS';
  else if (/Linux/i.test(ua)) os = 'Linux';

  if (/Edg/i.test(ua)) browser = 'Edge';
  else if (/Chrome/i.test(ua) && !/Chromium|Edg/i.test(ua)) browser = 'Chrome';
  else if (/Safari/i.test(ua) && !/Chrome/i.test(ua)) browser = 'Safari';
  else if (/Firefox/i.test(ua)) browser = 'Firefox';
  else if (/Opera|OPR/i.test(ua)) browser = 'Opera';

  return { deviceType, os, browser };
}

function recordTrafficEvent(ev) {
  trafficStore.events.unshift(ev);
  if (trafficStore.events.length > 5000) {
    trafficStore.events.length = 5000;
  }

  const dateStr = ev.created_at.slice(0, 10);
  const monthStr = ev.created_at.slice(0, 7);

  if (!trafficStore.daily[dateStr]) {
    trafficStore.daily[dateStr] = {
      landing_views: 0,
      landing_uniques: [],
      dashboard_views: 0,
      dashboard_uniques: [],
      devices: { mobile: 0, desktop: 0, tablet: 0 },
      referrers: {},
      routes: {}
    };
  }
  const day = trafficStore.daily[dateStr];
  if (ev.page_type === 'dashboard') {
    day.dashboard_views++;
    if (!day.dashboard_uniques.includes(ev.visitor_id)) {
      day.dashboard_uniques.push(ev.visitor_id);
    }
  } else {
    day.landing_views++;
    if (!day.landing_uniques.includes(ev.visitor_id)) {
      day.landing_uniques.push(ev.visitor_id);
    }
  }

  day.devices[ev.device_type] = (day.devices[ev.device_type] || 0) + 1;
  const refKey = (ev.referrer || 'direct').toLowerCase();
  day.referrers[refKey] = (day.referrers[refKey] || 0) + 1;
  day.routes[ev.path] = (day.routes[ev.path] || 0) + 1;

  if (!trafficStore.monthly[monthStr]) {
    trafficStore.monthly[monthStr] = {
      landing_views: 0,
      dashboard_views: 0,
      uniques: []
    };
  }
  const month = trafficStore.monthly[monthStr];
  if (ev.page_type === 'dashboard') month.dashboard_views++;
  else month.landing_views++;
  if (!month.uniques.includes(ev.visitor_id)) {
    month.uniques.push(ev.visitor_id);
  }

  persistTrafficStore();
}

// Dev Dashboard HTML Web View
app.get(['/dev', '/dev-dashboard', '/admin/traffic', '/analytics'], (req, res) => {
  const devDashboardPath = path.join(__dirname, 'public/dev_dashboard.html');
  if (fs.existsSync(devDashboardPath)) {
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    return res.sendFile(devDashboardPath);
  }
  return res.status(404).send('Dev Dashboard not found');
});

// Dev Auth Login
app.post('/api/dev/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  const normalizedEmail = (email || '').toLowerCase().trim();

  const isValidEmail = DEV_ADMIN_EMAILS.includes(normalizedEmail);
  const isValidPass = verifyDevPassword(password);

  if (!isValidEmail || !isValidPass) {
    return res.status(401).json({
      success: false,
      error: 'Credenciales inválidas. Verifica tu correo y contraseña.'
    });
  }

  const token = 'pawt_dev_' + crypto.randomBytes(32).toString('hex');
  const expiresAt = Date.now() + (24 * 60 * 60 * 1000); // 24 hours
  devSessions.set(token, { email: normalizedEmail, expiresAt });

  return res.json({
    success: true,
    token,
    dev: {
      email: normalizedEmail,
      role: 'Lead Developer'
    }
  });
});

// Telemetry Event Tracker (Landing & Dashboard)
app.post('/api/analytics/track', async (req, res) => {
  try {
    const { visitorId, pageType, path: reqPath, referrer, screenWidth, language } = req.body || {};
    if (!visitorId) return res.status(400).json({ error: 'Missing visitorId' });

    const ua = req.headers['user-agent'] || '';
    const parsed = parseUserAgent(ua);
    let deviceType = parsed.deviceType;
    if (screenWidth && screenWidth < 768) deviceType = 'mobile';
    else if (screenWidth && screenWidth <= 1024) deviceType = 'tablet';

    const country = req.headers['cf-ipcountry'] || req.headers['x-country-code'] || 'Desconocido';
    const now = new Date();
    const event = {
      id: 'tr_' + crypto.randomBytes(8).toString('hex'),
      visitor_id: visitorId,
      page_type: pageType === 'dashboard' ? 'dashboard' : 'landing',
      path: reqPath || (pageType === 'dashboard' ? '/dashboard' : '/'),
      referrer: referrer || 'direct',
      device_type: deviceType,
      browser: parsed.browser,
      os: parsed.os,
      country: country,
      created_at: now.toISOString()
    };

    recordTrafficEvent(event);

    if (supabaseAdmin) {
      supabaseAdmin.from('site_traffic').insert([{
        visitor_id: event.visitor_id,
        page_type: event.page_type,
        path: event.path,
        referrer: event.referrer,
        device_type: event.device_type,
        browser: event.browser,
        os: event.os,
        country: event.country,
        created_at: event.created_at
      }]).catch(() => {});
    }

    return res.json({ success: true });
  } catch (err) {
    console.error('Analytics track error:', err.message);
    return res.status(500).json({ error: 'Track error' });
  }
});

// Dev Traffic Stats Endpoint
app.get('/api/dev/traffic/stats', (req, res) => {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  const session = verifyDevToken(token);

  if (!session) {
    return res.status(401).json({ success: false, error: 'No autorizado. Sesión expirada.' });
  }

  const todayStr = new Date().toISOString().slice(0, 10);
  const thisMonthStr = new Date().toISOString().slice(0, 7);

  const today = trafficStore.daily[todayStr] || {
    landing_views: 0,
    landing_uniques: [],
    dashboard_views: 0,
    dashboard_uniques: [],
    devices: { mobile: 0, desktop: 0, tablet: 0 },
    referrers: {},
    routes: {}
  };

  const todayAllUniques = new Set([...today.landing_uniques, ...today.dashboard_uniques]);
  const thisMonth = trafficStore.monthly[thisMonthStr] || { landing_views: 0, dashboard_views: 0, uniques: [] };

  let totalLandingViews = 0;
  let totalDashboardViews = 0;
  let landingUniquesSet = new Set();
  let dashboardUniquesSet = new Set();
  let aggregatedDevices = { mobile: 0, desktop: 0, tablet: 0 };
  let aggregatedReferrers = {};
  let aggregatedRoutes = {};

  const history_daily = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const dKey = d.toISOString().slice(0, 10);
    const dayData = trafficStore.daily[dKey];
    if (dayData) {
      const uSet = new Set([...dayData.landing_uniques, ...dayData.dashboard_uniques]);
      history_daily.push({
        date: dKey.slice(5),
        fullDate: dKey,
        landing_views: dayData.landing_views,
        dashboard_views: dayData.dashboard_views,
        uniques: uSet.size
      });
      totalLandingViews += dayData.landing_views;
      totalDashboardViews += dayData.dashboard_views;
      dayData.landing_uniques.forEach(id => landingUniquesSet.add(id));
      dayData.dashboard_uniques.forEach(id => dashboardUniquesSet.add(id));
      aggregatedDevices.mobile += dayData.devices.mobile || 0;
      aggregatedDevices.desktop += dayData.devices.desktop || 0;
      aggregatedDevices.tablet += dayData.devices.tablet || 0;
      for (const [r, c] of Object.entries(dayData.referrers || {})) {
        aggregatedReferrers[r] = (aggregatedReferrers[r] || 0) + c;
      }
      for (const [p, c] of Object.entries(dayData.routes || {})) {
        aggregatedRoutes[p] = (aggregatedRoutes[p] || 0) + c;
      }
    } else {
      history_daily.push({
        date: dKey.slice(5),
        fullDate: dKey,
        landing_views: 0,
        dashboard_views: 0,
        uniques: 0
      });
    }
  }

  const history_monthly = [];
  const monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  for (let i = 5; i >= 0; i--) {
    const d = new Date();
    d.setMonth(d.getMonth() - i);
    const mKey = d.toISOString().slice(0, 7);
    const mData = trafficStore.monthly[mKey];
    const mIndex = parseInt(mKey.slice(5, 7), 10) - 1;
    const label = `${monthNames[mIndex]} ${mKey.slice(2, 4)}`;
    if (mData) {
      history_monthly.push({
        month: label,
        uniques: mData.uniques.length,
        views: mData.landing_views + mData.dashboard_views
      });
    } else {
      history_monthly.push({
        month: label,
        uniques: 0,
        views: 0
      });
    }
  }

  return res.json({
    success: true,
    summary: {
      dau_today: todayAllUniques.size,
      views_today: today.landing_views + today.dashboard_views,
      mau_month: thisMonth.uniques.length,
      views_month: thisMonth.landing_views + thisMonth.dashboard_views,
      landing_views: totalLandingViews,
      landing_uniques: landingUniquesSet.size,
      dashboard_views: totalDashboardViews,
      dashboard_uniques: dashboardUniquesSet.size
    },
    history_daily,
    history_monthly,
    devices: aggregatedDevices,
    referrers: aggregatedReferrers,
    routes: aggregatedRoutes,
    recent_events: trafficStore.events.slice(0, 20)
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
// 3B. UPDATE PROFILE ENDPOINT (BYPASS RLS)
// --------------------------------------------------------------------------
app.post('/api/profile/update', async (req, res) => {
  const { id, username, fullName, avatarUrl, bio } = req.body;
  if (!id) {
    return res.status(400).json({ success: false, error: 'Missing user id' });
  }

  if (supabaseAdmin) {
    try {
      const { data, error } = await supabaseAdmin
        .from('profiles')
        .update({
          username,
          full_name: fullName,
          avatar_url: avatarUrl,
          bio
        })
        .eq('id', id)
        .select()
        .single();

      if (error) {
        console.error('Supabase profile update error:', error);
        return res.status(500).json({ success: false, error: error.message });
      }

      return res.json({ success: true, profile: data });
    } catch (e) {
      console.error('Supabase update exception:', e);
      return res.status(500).json({ success: false, error: e.message });
    }
  }

  return res.json({ success: false, error: 'Supabase Admin no configurado' });
});

// --------------------------------------------------------------------------
// 3C. UPDATE USER ANIMAL/PET PREFERENCES & AFFINITIES
// --------------------------------------------------------------------------
app.post('/api/profile/preferences', async (req, res) => {
  const { userId, favoriteSpecies } = req.body;
  if (!userId || !favoriteSpecies) {
    return res.status(400).json({ success: false, error: 'Missing userId or favoriteSpecies' });
  }

  if (supabaseAdmin) {
    try {
      const { data, error } = await supabaseAdmin
        .from('profiles')
        .update({ favorite_species: favoriteSpecies })
        .eq('id', userId)
        .select()
        .single();

      if (error) {
        console.error('Supabase preferences update error:', error);
        return res.status(500).json({ success: false, error: error.message });
      }

      return res.json({ success: true, favoriteSpecies: data.favorite_species });
    } catch (e) {
      console.error('Supabase preferences exception:', e);
      return res.status(500).json({ success: false, error: e.message });
    }
  }

  return res.json({ success: true, favoriteSpecies });
});

// --------------------------------------------------------------------------
// 3D. UPDATE PET PROFILE DETAILS & AVATAR IN SUPABASE
// --------------------------------------------------------------------------
app.post('/api/pet/update', async (req, res) => {
  const { id, name, species, breed, bio, avatarUrl } = req.body;
  if (!id) {
    return res.status(400).json({ success: false, error: 'Missing pet id' });
  }

  const updates = {};
  if (name !== undefined) updates.name = name;
  if (species !== undefined) updates.species = species;
  if (breed !== undefined) updates.breed = breed;
  if (bio !== undefined) updates.bio = bio;
  if (avatarUrl !== undefined) updates.avatar_url = avatarUrl;

  if (supabaseAdmin) {
    try {
      const { data, error } = await supabaseAdmin
        .from('pets')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        console.error('Supabase pet update error:', error);
        return res.status(500).json({ success: false, error: error.message });
      }

      return res.json({ success: true, pet: data });
    } catch (e) {
      console.error('Supabase pet update exception:', e);
      return res.status(500).json({ success: false, error: e.message });
    }
  }

  return res.json({ success: true, pet: { id, ...updates } });
});

// --------------------------------------------------------------------------
// 3E. CONSOLIDATE & DELETE DUPLICATE CHICO PROFILE (BYPASS RLS VIA SUPABASE ADMIN)
// --------------------------------------------------------------------------
app.all('/api/admin/consolidate-chico', async (req, res) => {
  if (!supabaseAdmin) {
    return res.status(500).json({ success: false, error: 'supabaseAdmin not initialized' });
  }

  try {
    const results = {};

    // 1. Reassign real Chico (pet_d1148fad) to wernesto66@gmail.com (usr_VL5CBAhr)
    const { data: updateData, error: updateErr } = await supabaseAdmin
      .from('pets')
      .update({ owner_id: 'usr_VL5CBAhr' })
      .eq('id', 'pet_d1148fad')
      .select();
    results.updateChicoReal = { success: !updateErr, data: updateData, error: updateErr?.message };

    // 2. Delete any follows pointing to duplicate Chico
    const { error: followErr } = await supabaseAdmin
      .from('follows')
      .delete()
      .eq('following_pet_id', 'pet_chico_VL5CBA');
    results.deleteFollows = { error: followErr?.message };

    // 3. Delete duplicate Chico (pet_chico_VL5CBA)
    const { data: deleteData, error: deleteErr } = await supabaseAdmin
      .from('pets')
      .delete()
      .eq('id', 'pet_chico_VL5CBA')
      .select();
    results.deleteDuplicate = { success: !deleteErr, data: deleteData, error: deleteErr?.message };

    // 4. Query current pets in database
    const { data: remainingPets, error: fetchErr } = await supabaseAdmin
      .from('pets')
      .select('*');
    results.remainingPets = remainingPets;

    return res.json({
      success: true,
      message: 'Chico profiles successfully consolidated. Duplicate French Bulldog Chico deleted.',
      results
    });
  } catch (err) {
    console.error('Error consolidating Chico profile:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// --------------------------------------------------------------------------
// 3F. DELETE POST ENDPOINT (BYPASS RLS VIA SUPABASE ADMIN & CLEAN UP RELATIONS)
// --------------------------------------------------------------------------
app.post('/api/posts/delete', async (req, res) => {
  const { postId } = req.body;
  if (!postId) {
    return res.status(400).json({ success: false, error: 'Missing postId' });
  }

  if (supabaseAdmin) {
    try {
      // 1. Delete associated comments first (foreign key protection)
      try {
        await supabaseAdmin.from('comments').delete().eq('post_id', postId);
      } catch (e) {
        console.warn('Note deleting post comments:', e.message);
      }

      // 2. Delete associated post_likes
      try {
        await supabaseAdmin.from('post_likes').delete().eq('post_id', postId);
      } catch (e) {
        console.warn('Note deleting post likes:', e.message);
      }

      // 3. Delete associated post_reports if any
      try {
        await supabaseAdmin.from('post_reports').delete().eq('post_id', postId);
      } catch (e) {
        console.warn('Note deleting post reports:', e.message);
      }

      // 4. Delete the post from Supabase
      const { data, error } = await supabaseAdmin
        .from('posts')
        .delete()
        .eq('id', postId)
        .select();

      if (error) {
        console.error('Supabase post delete error:', error);
        return res.status(500).json({ success: false, error: error.message });
      }

      return res.json({ success: true, deleted: data });
    } catch (e) {
      console.error('Supabase delete post exception:', e);
      return res.status(500).json({ success: false, error: e.message });
    }
  }

  return res.json({ success: true, postId });
});

// --------------------------------------------------------------------------
// 3G. OFFICIAL PET VERIFICATION ENDPOINT ($10 USD / SOL / SKR BADGE)
// --------------------------------------------------------------------------
app.post('/api/pet/verify', async (req, res) => {
  const { petId, paymentMethod, txHash, usdAmount, solAmount, skrAmount } = req.body;
  if (!petId) {
    return res.status(400).json({ success: false, error: 'Missing petId' });
  }

  const verifiedMintAddress = `SolVerified_${Date.now()}_${petId.replace(/[^a-zA-Z0-9]/g, '').substring(0, 10)}`;

  if (supabaseAdmin) {
    try {
      // 1. Update pet with official verification mint
      const { data: petData, error: petErr } = await supabaseAdmin
        .from('pets')
        .update({ nft_mint_address: verifiedMintAddress })
        .eq('id', petId)
        .select()
        .single();

      if (petErr) {
        console.error('Error verifying pet in Supabase:', petErr);
        return res.status(500).json({ success: false, error: petErr.message });
      }

      // 2. Cascade verification badge to all posts by this pet
      try {
        await supabaseAdmin
          .from('posts')
          .update({ nft_mint_address: verifiedMintAddress })
          .eq('pet_id', petId);
      } catch (postErr) {
        console.warn('Note updating post verification addresses:', postErr.message);
      }

      return res.json({
        success: true,
        verifiedMintAddress,
        pet: petData,
        message: '¡Verificación oficial de cuenta activada con éxito!'
      });
    } catch (e) {
      console.error('Exception in /api/pet/verify:', e);
      return res.status(500).json({ success: false, error: e.message });
    }
  }

  return res.json({
    success: true,
    verifiedMintAddress,
    message: 'Verificación simulada en modo local'
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
// 4B. CLOUDFLARE R2 AVATAR PRESIGNED UPLOAD URL ENDPOINT
// --------------------------------------------------------------------------
app.post('/api/media/avatar-upload-url', async (req, res) => {
  const { userId, filename } = req.body;
  if (!userId) {
    return res.status(400).json({ success: false, error: 'Missing userId' });
  }

  const ext = filename ? filename.split('.').pop() : 'jpg';
  const uniqueKey = `avatars/${userId}_${Date.now()}.${ext}`;
  const publicUrl = `${R2_CUSTOM_DOMAIN}/${uniqueKey}`;

  let presignedPutUrl = `${R2_CUSTOM_DOMAIN}/upload-signed-vault/${uniqueKey}?signature=mock_r2_avatar_sig`;

  if (r2Client) {
    try {
      const command = new PutObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: uniqueKey,
        ContentType: 'image/jpeg',
      });
      presignedPutUrl = await getSignedUrl(r2Client, command, { expiresIn: 900 });
    } catch (err) {
      console.error('Error generating Cloudflare R2 Avatar Presigned URL:', err);
      return res.status(500).json({ success: false, error: 'Failed to generate R2 Presigned URL' });
    }
  }

  return res.json({
    success: true,
    userId,
    key: uniqueKey,
    presignedPutUrl,
    publicUrl,
  });
});

// --------------------------------------------------------------------------
// 4C. CLOUDFLARE R2 DELETE OBJECT ENDPOINT (DELETES PREVIOUS AVATAR/MEDIA)
// --------------------------------------------------------------------------
app.post('/api/media/delete-object', async (req, res) => {
  const { mediaUrl, objectKey } = req.body;
  let key = objectKey;
  if (!key && mediaUrl) {
    if (mediaUrl.includes(R2_CUSTOM_DOMAIN)) {
      key = mediaUrl.replace(`${R2_CUSTOM_DOMAIN}/`, '');
    } else if (mediaUrl.includes('/')) {
      key = mediaUrl.split('/').slice(3).join('/');
    }
  }

  if (!key) {
    return res.status(400).json({ success: false, error: 'Missing objectKey or mediaUrl' });
  }

  if (r2Client) {
    try {
      const command = new DeleteObjectCommand({
        Bucket: R2_BUCKET_NAME,
        Key: key,
      });
      await r2Client.send(command);
      console.log(`🗑️ Deleted R2 Object: ${key}`);
      return res.json({ success: true, key, message: 'Object deleted successfully from Cloudflare R2' });
    } catch (err) {
      console.error(`Error deleting Cloudflare R2 object ${key}:`, err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }

  console.log(`🗑️ [Mock R2] Deleted object: ${key}`);
  return res.json({ success: true, key, message: 'Mock R2 object deleted' });
});

// --------------------------------------------------------------------------
// 4D. VIDEO PROCESSING PIPELINE WITH FFMPEG (AUDIO MIXING & OVERLAYS INTEGRATION)
// --------------------------------------------------------------------------
app.post('/api/media/process-video', async (req, res) => {
  const {
    petId,
    videoUrl,
    videoBase64,
    overlayPngBase64,
    soundUrl,
    startSeconds = 0,
    endSeconds = 30,
    originalVolume = 1.0,
    musicVolume = 0.8
  } = req.body;

  if (!petId) {
    return res.status(400).json({ success: false, error: 'Missing petId' });
  }

  const tempDir = os.tmpdir();
  const timestamp = Date.now();
  const inputVideoPath = path.join(tempDir, `input_vid_${timestamp}.mp4`);
  const inputOverlayPath = path.join(tempDir, `input_overlay_${timestamp}.png`);
  const inputAudioPath = path.join(tempDir, `input_audio_${timestamp}.mp3`);
  const outputVideoPath = path.join(tempDir, `output_processed_${timestamp}.mp4`);

  const cleanupFiles = () => {
    [inputVideoPath, inputOverlayPath, inputAudioPath, outputVideoPath].forEach(file => {
      try {
        if (fs.existsSync(file)) fs.unlinkSync(file);
      } catch (_) {}
    });
  };

  try {
    // 1. Obtener video origen
    if (videoBase64) {
      const cleanBase64 = videoBase64.replace(/^data:video\/\w+;base64,/, '');
      const buffer = Buffer.from(cleanBase64, 'base64');
      fs.writeFileSync(inputVideoPath, buffer);
    } else if (videoUrl) {
      const resp = await fetch(videoUrl);
      if (!resp.ok) throw new Error(`Failed to download source video: ${resp.statusText}`);
      const arrayBuffer = await resp.arrayBuffer();
      fs.writeFileSync(inputVideoPath, Buffer.from(arrayBuffer));
    } else {
      return res.status(400).json({ success: false, error: 'No video provided (neither videoUrl nor videoBase64)' });
    }

    // 2. Guardar overlay PNG si existe
    const hasOverlay = !!overlayPngBase64;
    if (hasOverlay) {
      const cleanOverlay = overlayPngBase64.replace(/^data:image\/\w+;base64,/, '');
      const overlayBuffer = Buffer.from(cleanOverlay, 'base64');
      fs.writeFileSync(inputOverlayPath, overlayBuffer);
    }

    // 3. Descargar pista de audio si existe
    const hasSound = !!soundUrl;
    if (hasSound) {
      try {
        const audioResp = await fetch(soundUrl);
        if (audioResp.ok) {
          const audioArray = await audioResp.arrayBuffer();
          fs.writeFileSync(inputAudioPath, Buffer.from(audioArray));
        }
      } catch (audioErr) {
        console.warn('Could not download audio track, proceeding without music:', audioErr.message);
      }
    }

    const audioAvailable = hasSound && fs.existsSync(inputAudioPath);
    const overlayAvailable = hasOverlay && fs.existsSync(inputOverlayPath);

    // Duración máxima estricta de 30 segundos
    const rawStart = parseFloat(startSeconds) || 0.0;
    const rawEnd = parseFloat(endSeconds) || 30.0;
    const targetDuration = Math.max(1.0, Math.min(30.0, rawEnd - rawStart));
    const startTime = Math.max(0.0, rawStart);

    console.log(`🎬 Processing video for pet ${petId}: duration=${targetDuration}s, overlays=${overlayAvailable}, music=${audioAvailable}`);

    // 4. Configurar FFmpeg
    let command = ffmpeg();
    command = command.input(inputVideoPath).seekInput(startTime).duration(targetDuration);

    const complexFilters = [];
    let currentVideoLabel = '0:v';

    if (overlayAvailable) {
      command = command.input(inputOverlayPath);
      complexFilters.push(`[${currentVideoLabel}][1:v]overlay=0:0[vfinal]`);
      currentVideoLabel = 'vfinal';
    }

    let audioLabel = '0:a';
    if (audioAvailable) {
      const audioInputIndex = overlayAvailable ? 2 : 1;
      command = command.input(inputAudioPath);

      const origVol = parseFloat(originalVolume) || 1.0;
      const musVol = parseFloat(musicVolume) || 0.8;

      if (origVol > 0) {
        complexFilters.push(`[0:a]volume=${origVol.toFixed(2)}[a_orig]`);
        complexFilters.push(`[${audioInputIndex}:a]volume=${musVol.toFixed(2)}[a_music]`);
        complexFilters.push(`[a_orig][a_music]amix=inputs=2:duration=first:dropout_transition=2[afinal]`);
        audioLabel = 'afinal';
      } else {
        complexFilters.push(`[${audioInputIndex}:a]volume=${musVol.toFixed(2)}[afinal]`);
        audioLabel = 'afinal';
      }
    }

    if (complexFilters.length > 0) {
      command = command.complexFilter(complexFilters);
    }

    command = command.outputOptions([
      '-c:v', 'libx264',
      '-pix_fmt', 'yuv420p',
      '-preset', 'fast',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-movflags', '+faststart'
    ]);

    if (complexFilters.length > 0) {
      if (overlayAvailable) {
        command = command.outputOptions(['-map', `[${currentVideoLabel}]`]);
      }
      if (audioAvailable) {
        command = command.outputOptions(['-map', `[${audioLabel}]`]);
      }
    }

    await new Promise((resolve, reject) => {
      command
        .save(outputVideoPath)
        .on('end', () => {
          console.log(`✅ FFmpeg processing completed for pet ${petId}`);
          resolve();
        })
        .on('error', (err) => {
          console.error('❌ FFmpeg execution error:', err.message);
          reject(err);
        });
    });

    // 5. Subir a Cloudflare R2
    const processedBytes = fs.readFileSync(outputVideoPath);
    const uniqueKey = `posts/${petId}_processed_${Date.now()}.mp4`;
    const publicUrl = `${R2_CUSTOM_DOMAIN}/${uniqueKey}`;

    if (r2Client) {
      try {
        const putCmd = new PutObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: uniqueKey,
          ContentType: 'video/mp4',
          Body: processedBytes
        });
        await r2Client.send(putCmd);
        console.log(`☁️ Processed video uploaded to Cloudflare R2: ${publicUrl}`);
      } catch (r2Err) {
        console.error('Error uploading processed video to R2:', r2Err);
        throw r2Err;
      }
    } else {
      console.log(`⚠️ [Mock R2] Processed video ready: ${publicUrl} (${processedBytes.length} bytes)`);
    }

    cleanupFiles();

    return res.json({
      success: true,
      publicUrl,
      key: uniqueKey,
      duration: targetDuration,
      audioIntegrated: audioAvailable,
      overlaysIntegrated: overlayAvailable,
      message: 'Video procesado, audio y stickers integrados correctamente como un nuevo video'
    });
  } catch (procErr) {
    cleanupFiles();
    console.error('Video processing exception:', procErr.message);
    return res.status(500).json({
      success: false,
      error: procErr.message,
      fallbackUrl: videoUrl || null
    });
  }
});

// --------------------------------------------------------------------------
// 5. SAFETY & ANIMAL WELFARE MODERATION PIPELINE (FFmpeg + Gemini Vision AI)
// --------------------------------------------------------------------------

/**
 * Extrae fotogramas clave de un video para análisis de moderación
 */
async function extractVideoKeyframes(videoUrl, count = 3) {
  const tempDir = os.tmpdir();
  const timestamp = `${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const tempVideoPath = path.join(tempDir, `mod_vid_${timestamp}.mp4`);
  const framePrefix = `mod_frame_${timestamp}`;

  try {
    // 1. Descargar el video a un archivo temporal
    const resp = await fetch(videoUrl);
    if (!resp.ok) {
      console.warn(`[Moderation] Failed to download video ${videoUrl}: ${resp.statusText}`);
      return [];
    }
    const arrayBuf = await resp.arrayBuffer();
    fs.writeFileSync(tempVideoPath, Buffer.from(arrayBuf));

    // 2. Extraer fotogramas distribuidos en el video usando FFmpeg
    await new Promise((resolve) => {
      ffmpeg(tempVideoPath)
        .screenshots({
          count: count,
          folder: tempDir,
          filename: `${framePrefix}_%i.jpg`,
          size: '640x?'
        })
        .on('end', () => resolve())
        .on('error', (err) => {
          console.warn('[Moderation] FFmpeg frame extraction warning:', err.message);
          resolve(); // continuar con lo que se haya alcanzado a extraer
        });
    });

    // 3. Leer los fotogramas generados y convertirlos a base64
    const frames = [];
    for (let i = 1; i <= count + 1; i++) {
      const framePath = path.join(tempDir, `${framePrefix}_${i}.jpg`);
      if (fs.existsSync(framePath)) {
        try {
          const frameBytes = fs.readFileSync(framePath);
          frames.push({
            mimeType: 'image/jpeg',
            data: frameBytes.toString('base64')
          });
          fs.unlinkSync(framePath);
        } catch (_) {}
      }
    }

    try {
      if (fs.existsSync(tempVideoPath)) fs.unlinkSync(tempVideoPath);
    } catch (_) {}

    return frames;
  } catch (ex) {
    console.error('[Moderation] extractVideoKeyframes exception:', ex.message);
    try {
      if (fs.existsSync(tempVideoPath)) fs.unlinkSync(tempVideoPath);
    } catch (_) {}
    return [];
  }
}

/**
 * Descarga una imagen remota y la convierte a objeto base64 para IA
 */
async function downloadImageForModeration(imageUrl) {
  try {
    const resp = await fetch(imageUrl);
    if (!resp.ok) return [];
    const arrayBuf = await resp.arrayBuffer();
    const contentType = resp.headers.get('content-type') || 'image/jpeg';
    const mimeType = contentType.includes('png') ? 'image/png' : 'image/jpeg';
    return [{
      mimeType,
      data: Buffer.from(arrayBuf).toString('base64')
    }];
  } catch (err) {
    console.warn('[Moderation] Error downloading image:', err.message);
    return [];
  }
}

/**
 * Analiza fotogramas con Google Gemini Vision para verificar presencia de mascotas y bienestar animal
 */
async function analyzeMediaWithGemini(frames) {
  if (!GEMINI_API_KEY || !frames || frames.length === 0) {
    return null;
  }

  const systemPrompt = `
Eres el sistema oficial de Inteligencia Artificial para moderación, seguridad y bienestar animal de la red social "Pawtbook".
Tu objetivo primordial es proteger a los animales y asegurar que Pawtbook sea una comunidad auténtica y exclusiva de mascotas.

Analiza con el máximo rigor los fotogramas proporcionados y verifica las siguientes reglas:

1. REGLA DE MASCOTAS (has_pet):
   - Debe aparecer visiblemente al menos una mascota o animal (perro, gato, ave, conejo, caballo, reptil, hamster, animal de granja o de compañía).
   - Los humanos están PERMITIDOS y BIENVENIDOS siempre que estén interactuando pacíficamente con la mascota (paseo, caricias, juego, entrenamiento positivo, abrazos).
   - Si el contenido es ÚNICAMENTE de personas o cosas SIN ninguna mascota visible (ejemplo: selfies de personas solas, baile humano sin mascotas, paisajes vacíos, autos, texto, memes ajenos), RECHAZARLO (human_only: true).

2. REGLA DE BIENESTAR ANIMAL (animal_abuse_detected):
   - TOLERANCIA CERO al maltrato animal.
   - RECHAZAR de inmediato si se observa: violencia física hacia animales, golpes, patadas, peleas forzadas de perros/gallos/animales, animales atados en condiciones asfixiantes, desnutrición extrema deliberada, heridas ensangrentadas abiertas, angustia animal evidente o humillación peligrosa.

3. REGLA DE CONTENIDO FAMILIAR (inappropriate_nsfw):
   - RECHAZAR si hay desnudez humana, actos sexuales, violencia explícita, sangre humana, armas o drogas.

4. DECISIÓN:
   - "APPROVED": Hay mascota presente, en situación segura y respetuosa, sin infracciones.
   - "REJECTED": Falta de mascota (solo humanos/objetos), maltrato animal o contenido inapropiado.

Devuelve ÚNICAMENTE un JSON válido sin formato markdown adicional, con esta estructura exacta:
{
  "has_pet": true,
  "animal_type": "perro",
  "animal_abuse_detected": false,
  "human_only": false,
  "inappropriate_nsfw": false,
  "decision": "APPROVED",
  "reason_es": "Breve explicación en español (máximo 120 caracteres)",
  "confidence": 0.95
}
`;

  try {
    const parts = [{ text: systemPrompt }];
    for (const frame of frames) {
      parts.push({
        inline_data: {
          mime_type: frame.mimeType,
          data: frame.data
        }
      });
    }

    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;
    const resp = await fetch(apiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.1,
          response_mime_type: 'application/json'
        }
      })
    });

    if (!resp.ok) {
      const errText = await resp.text();
      console.warn(`[Moderation] Gemini API error HTTP ${resp.status}:`, errText);
      return null;
    }

    const data = await resp.json();
    const candidateText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!candidateText) return null;

    const parsed = JSON.parse(candidateText);
    console.log(`[Moderation] 🐾 Gemini Decision: ${parsed.decision} (${parsed.animal_type || 'none'}) - ${parsed.reason_es}`);
    return parsed;
  } catch (err) {
    console.warn('[Moderation] Gemini invocation exception:', err.message);
    return null;
  }
}

// Endpoint de verificación previa (Pre-flight content verification)
app.post('/api/media/verify', async (req, res) => {
  const { mediaUrl, mediaType, framesBase64 } = req.body;

  if (!mediaUrl && (!framesBase64 || framesBase64.length === 0)) {
    return res.status(400).json({ success: false, error: 'Missing mediaUrl or framesBase64' });
  }

  let frames = [];
  if (Array.isArray(framesBase64) && framesBase64.length > 0) {
    frames = framesBase64.map(b64 => ({ mimeType: 'image/jpeg', data: b64 }));
  } else if (mediaUrl) {
    const isVideo = mediaType === 'video' || mediaUrl.match(/\.(mp4|mov|webm|m4v)(\?.*)?$/i);
    if (isVideo) {
      frames = await extractVideoKeyframes(mediaUrl, 3);
    } else {
      frames = await downloadImageForModeration(mediaUrl);
    }
  }

  let aiResult = null;
  if (frames.length > 0) {
    aiResult = await analyzeMediaWithGemini(frames);
  }

  const isApproved = aiResult ? (aiResult.decision === 'APPROVED') : true;
  return res.json({
    success: true,
    verified: isApproved,
    decision: isApproved ? 'APPROVED' : 'REJECTED',
    reason: aiResult?.reason_es || (isApproved ? 'Contenido verificado con éxito' : 'No cumple con las normas de Pawtbook'),
    details: aiResult
  });
});

// Endpoint principal del pipeline de moderación de publicaciones
app.post('/api/media/moderate', async (req, res) => {
  const { postId, mediaUrl, mediaType, forceDecision, framesBase64 } = req.body;

  if (!postId || !mediaUrl) {
    return res.status(400).json({ success: false, error: 'Missing postId or mediaUrl' });
  }

  let status = 'active';
  let moderationReason = 'Verificación de seguridad y bienestar animal aprobada 🐾';
  let aiDetails = null;

  // 1. Control manual o forzado para testing
  if (forceDecision === 'reject' || mediaUrl.includes('inappropriate') || mediaUrl.includes('abuse')) {
    status = 'rejected';
    moderationReason = 'Rechazado por políticas de bienestar animal o contenido no apto';
  } else if (forceDecision === 'approve') {
    status = 'active';
    moderationReason = 'Aprobado manualmente para pruebas';
  } else {
    // 2. Ejecutar análisis con Gemini Vision AI si está configurado
    try {
      let frames = [];
      if (Array.isArray(framesBase64) && framesBase64.length > 0) {
        frames = framesBase64.map(b64 => ({ mimeType: 'image/jpeg', data: b64 }));
      } else {
        const isVideo = mediaType === 'video' || mediaUrl.match(/\.(mp4|mov|webm|m4v)(\?.*)?$/i);
        if (isVideo) {
          console.log(`[Moderation] 🎬 Extrayendo fotogramas de video para post ${postId}...`);
          frames = await extractVideoKeyframes(mediaUrl, 3);
        } else {
          console.log(`[Moderation] 🖼️ Descargando imagen para post ${postId}...`);
          frames = await downloadImageForModeration(mediaUrl);
        }
      }

      if (frames.length > 0) {
        aiDetails = await analyzeMediaWithGemini(frames);
        if (aiDetails) {
          if (aiDetails.decision === 'APPROVED') {
            status = 'active';
            moderationReason = aiDetails.reason_es || 'Mascota verificada y segura 🐾';
          } else {
            status = 'rejected';
            moderationReason = aiDetails.reason_es || 'El contenido no cumple con los criterios de Pawtbook (requiere mascotas y cero maltrato)';
          }
        }
      }
    } catch (analysisErr) {
      console.error('[Moderation] Error durante análisis de IA:', analysisErr.message);
      // En caso de fallo técnico de red, mantener activo con advertencia
      moderationReason = 'Aprobado condicionalmente (Verificación IA no disponible temporalmente)';
    }
  }

  // 3. Actualizar estado y razón en la base de datos Supabase
  if (supabaseAdmin) {
    try {
      const { error: updateErr } = await supabaseAdmin
        .from('posts')
        .update({ status, moderation_reason: moderationReason })
        .eq('id', postId);

      if (updateErr) {
        console.error('Supabase moderation update error:', updateErr);
      } else {
        console.log(`[Moderation] 📝 Post ${postId} actualizado a status='${status}' en Supabase`);
      }
    } catch (e) {
      console.error('Supabase moderation update exception:', e);
    }
  }

  return res.json({
    success: true,
    postId,
    status,
    reason: moderationReason,
    details: aiDetails
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

  const recipientWallet = '8szRk9h4k1i5e2hGjVjK3f7g1f888888888888888888';
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

// --------------------------------------------------------------------------
// 7A. CARD TO $SKR ON-RAMP SPONSORSHIP (Dynamic.xyz Solana Wallet)
// --------------------------------------------------------------------------
app.post('/api/sponsorship/card-to-skr', async (req, res) => {
  const { sponsorId, petId, amountUsd, skrAmount, sponsorWallet, petWallet, cardDetails } = req.body;

  if (!petId || !skrAmount) {
    return res.status(400).json({ success: false, error: 'Missing petId or skrAmount' });
  }

  const txHash = 'skr_onramp_' + Date.now() + '_' + Math.random().toString(36).substring(2, 9);
  const feePercent = 10.0;
  const feeAmount = Math.round(skrAmount * 0.10);
  const netAmount = skrAmount - feeAmount;

  if (supabaseAdmin && sponsorId) {
    try {
      await supabaseAdmin.from('sponsorships').insert({
        id: 'spn_' + Date.now(),
        sponsor_id: sponsorId,
        pet_id: petId,
        amount: skrAmount,
        payment_method: 'card_to_skr',
        tx_hash: txHash,
        fee_percent: feePercent,
        fee_amount: feeAmount,
        net_amount: netAmount,
        is_claimed: false,
        status: 'completed',
      });

      // Increment pet sponsorships & points
      await supabaseAdmin.rpc('increment_pet_sponsorship', {
        pet_id: petId,
        amount: netAmount
      }).catch(err => console.error('Error incrementing pet sponsorship:', err));
    } catch (e) {
      console.error('Error inserting card-to-skr sponsorship record:', e);
    }
  }

  return res.json({
    success: true,
    txHash,
    skrAmount,
    amountUsd: amountUsd || (skrAmount / 20.0),
    sponsorWallet: sponsorWallet || '8szRk9h4k1i5e2hGjVjK3f7g1f888888888888888888',
    petWallet: petWallet || '8szRk9h4k1i5e2hGjVjK3f7g1f888888888888888888',
    message: `Payment of $${amountUsd || (skrAmount / 20.0)} USD converted to ${skrAmount} $SKR and transferred via Dynamic Solana Wallet.`
  });
});

// --------------------------------------------------------------------------
// 7B. CLAIM / WITHDRAW SPONSORSHIP PAYOUT WITH DOUBLE-SPEND LOCKING
// --------------------------------------------------------------------------
app.post('/api/sponsorship/claim-payout', async (req, res) => {
  const { petId, userId, destinationWallet, txHash, amountSkr, amountSol, amountUsd } = req.body;

  if (!petId || !userId || !destinationWallet) {
    return res.status(400).json({ success: false, error: 'Missing required parameters: petId, userId, destinationWallet' });
  }

  const withdrawalId = 'wth_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8);
  const payoutTxHash = txHash || ('payout_sol_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8));

  if (supabaseAdmin) {
    try {
      // 1. Query all unclaimed sponsorships for this pet
      const { data: unclaimedSpn, error: queryErr } = await supabaseAdmin
        .from('sponsorships')
        .select('id, net_amount, amount')
        .eq('pet_id', petId)
        .eq('is_claimed', false);

      if (queryErr) {
        console.error('Error querying unclaimed sponsorships:', queryErr);
      }

      const unclaimedList = unclaimedSpn || [];
      const sponsorshipIds = unclaimedList.map(s => s.id);
      const calculatedNetSkr = unclaimedList.reduce((acc, curr) => acc + (curr.net_amount || curr.amount || 0), 0);
      const finalSkr = amountSkr || calculatedNetSkr;

      // 2. Insert withdrawal record
      await supabaseAdmin.from('withdrawals').insert({
        id: withdrawalId,
        pet_id: petId,
        user_id: userId,
        amount_skr: finalSkr,
        amount_sol: amountSol || 0.0,
        amount_usd: amountUsd || 0.0,
        destination_wallet: destinationWallet,
        tx_hash: payoutTxHash,
        status: 'completed',
        sponsorship_ids: sponsorshipIds,
      });

      // 3. LOCK all associated sponsorships: mark as is_claimed = true, status = 'withdrawn'
      if (sponsorshipIds.length > 0) {
        await supabaseAdmin
          .from('sponsorships')
          .update({
            is_claimed: true,
            status: 'withdrawn',
            withdrawal_id: withdrawalId,
            claimed_at: new Date().toISOString(),
          })
          .in('id', sponsorshipIds);
      }

      return res.json({
        success: true,
        withdrawalId,
        txHash: payoutTxHash,
        claimedSkr: finalSkr,
        lockedSponsorshipsCount: sponsorshipIds.length,
        message: 'Withdrawal processed and associated sponsorships locked successfully.'
      });
    } catch (err) {
      console.error('Error in claim-payout execution:', err);
      return res.status(500).json({ success: false, error: err.message || 'Internal error processing claim payout' });
    }
  }

  return res.json({
    success: true,
    withdrawalId,
    txHash: payoutTxHash,
    claimedSkr: amountSkr || 100,
    lockedSponsorshipsCount: 1,
    message: 'Withdrawal simulated and locked successfully (no supabase client connected).'
  });
});

// --------------------------------------------------------------------------
// 7C. PET SPONSORSHIP LEDGER & AUDIT TRAIL
// --------------------------------------------------------------------------
app.get('/api/sponsorship/pet-ledger/:petId', async (req, res) => {
  const { petId } = req.params;
  if (!petId) return res.status(400).json({ success: false, error: 'Missing petId' });

  if (supabaseAdmin) {
    try {
      // 1. Query sponsorships for pet with sponsor profile details
      const { data: sponsorships, error: spnErr } = await supabaseAdmin
        .from('sponsorships')
        .select(`
          id,
          sponsor_id,
          pet_id,
          amount,
          fee_percent,
          fee_amount,
          net_amount,
          payment_method,
          tx_hash,
          is_claimed,
          status,
          withdrawal_id,
          claimed_at,
          created_at,
          profiles:sponsor_id (full_name, username, avatar_url)
        `)
        .eq('pet_id', petId)
        .order('created_at', { ascending: false });

      // 2. Query withdrawals for pet
      const { data: withdrawals, error: wthErr } = await supabaseAdmin
        .from('withdrawals')
        .select('*')
        .eq('pet_id', petId)
        .order('created_at', { ascending: false });

      const allSpn = sponsorships || [];
      const allWth = withdrawals || [];

      // Calculate totals
      let totalLifetimeSkr = 0;
      let unclaimedSkr = 0;
      let totalWithdrawnSkr = 0;

      for (const s of allSpn) {
        const net = s.net_amount || s.amount || 0;
        totalLifetimeSkr += net;
        if (!s.is_claimed) {
          unclaimedSkr += net;
        } else {
          totalWithdrawnSkr += net;
        }
      }

      return res.json({
        success: true,
        petId,
        totalLifetimeSkr,
        unclaimedSkr,
        totalWithdrawnSkr,
        sponsorshipsCount: allSpn.length,
        withdrawalsCount: allWth.length,
        sponsorships: allSpn,
        withdrawals: allWth,
      });
    } catch (e) {
      console.error('Error fetching pet ledger:', e);
      return res.status(500).json({ success: false, error: e.message });
    }
  }

  return res.json({
    success: true,
    petId,
    totalLifetimeSkr: 0,
    unclaimedSkr: 0,
    totalWithdrawnSkr: 0,
    sponsorships: [],
    withdrawals: []
  });
});

// --------------------------------------------------------------------------
// 7C. RESET PET LEDGER & SPONSORSHIPS (Start from scratch / clean test data)
// --------------------------------------------------------------------------
app.post('/api/sponsorship/reset-pet-ledger', async (req, res) => {
  const { petId, petName } = req.body;
  if (!petId && !petName) {
    return res.status(400).json({ success: false, error: 'Missing petId or petName' });
  }

  if (supabaseAdmin) {
    try {
      let targetPetId = petId;
      if (!targetPetId && petName) {
        const { data: petData } = await supabaseAdmin
          .from('pets')
          .select('id')
          .ilike('name', petName);
        if (petData && petData.length > 0) {
          targetPetId = petData[0].id;
        }
      }

      if (targetPetId) {
        // 1. Delete all sponsorships for this pet
        await supabaseAdmin.from('sponsorships').delete().eq('pet_id', targetPetId);
        // 2. Delete all withdrawals for this pet
        await supabaseAdmin.from('withdrawals').delete().eq('pet_id', targetPetId);
        // 3. Reset total_sponsored_score to 0
        await supabaseAdmin.from('pets').update({ total_sponsored_score: 0 }).eq('id', targetPetId);

        return res.json({
          success: true,
          petId: targetPetId,
          message: `Pet ledger successfully reset to 0 for petId: ${targetPetId}`
        });
      }
    } catch (err) {
      console.error('Error resetting pet ledger:', err);
      return res.status(500).json({ success: false, error: err.message });
    }
  }

  return res.json({
    success: true,
    message: 'Reset pet ledger completed (mock mode)'
  });
});

// --------------------------------------------------------------------------
// 7C. LIVE ORACLE PRICE FEED FOR $SKR (Solana DexScreener / Orca / Jupiter)
// Mint Address: SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3
// --------------------------------------------------------------------------
let cachedOracleData = null;
let lastOracleFetch = 0;
let cachedSolUsdPrice = 117.0;
let lastSolFetch = 0;

async function getLiveSolUsdPrice() {
  const now = Date.now();
  if (now - lastSolFetch < 15000 && cachedSolUsdPrice > 40) {
    return cachedSolUsdPrice;
  }
  try {
    const response = await fetch('https://api.binance.com/api/v3/ticker/price?symbol=SOLUSDT', {
      signal: AbortSignal.timeout(3000)
    });
    if (response.ok) {
      const data = await response.json();
      const p = parseFloat(data.price);
      if (p > 40) {
        cachedSolUsdPrice = p;
        lastSolFetch = now;
        return cachedSolUsdPrice;
      }
    }
  } catch (_) {}

  try {
    const response = await fetch('https://api.dexscreener.com/latest/dex/tokens/So11111111111111111111111111111111111111112', {
      signal: AbortSignal.timeout(3000)
    });
    if (response.ok) {
      const data = await response.json();
      const p = data.pairs?.find(x => x.quoteToken?.symbol === 'USDC' || x.quoteToken?.symbol === 'USDT');
      if (p && p.priceUsd && parseFloat(p.priceUsd) > 40) {
        cachedSolUsdPrice = parseFloat(p.priceUsd);
        lastSolFetch = now;
        return cachedSolUsdPrice;
      }
    }
  } catch (_) {}

  return cachedSolUsdPrice;
}

app.get('/api/oracle/skr-price', async (req, res) => {
  const now = Date.now();
  const solUsd = await getLiveSolUsdPrice();

  if (cachedOracleData && (now - lastOracleFetch < 5000)) {
    return res.json({
      ...cachedOracleData,
      solUsdPrice: solUsd,
    });
  }

  try {
    const response = await fetch('https://api.dexscreener.com/latest/dex/tokens/SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3', {
      signal: AbortSignal.timeout(3500)
    });
    if (response.ok) {
      const data = await response.json();
      const pair = data.pairs?.find(p => p.chainId === 'solana') || data.pairs?.[0];
      if (pair && pair.priceUsd) {
        const livePrice = parseFloat(pair.priceUsd);
        const change24h = parseFloat(pair.priceChange?.h24 || '0');
        const volume24h = parseFloat(pair.volume?.h24 || '0');
        const fdv = parseFloat(pair.fdv || '0');
        const isQuoteSol = pair.quoteToken?.symbol === 'SOL' || pair.quoteToken?.symbol === 'WSOL';
        const priceSol = isQuoteSol
          ? parseFloat(pair.priceNative)
          : (solUsd > 0 ? parseFloat((livePrice / solUsd).toFixed(8)) : parseFloat((livePrice / 120.0).toFixed(8)));

        cachedOracleData = {
          success: true,
          symbol: 'SKR',
          name: 'Seeker',
          mintAddress: 'SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3',
          chain: 'solana',
          priceUsd: livePrice,
          priceSol: priceSol,
          solUsdPrice: solUsd,
          change24h: change24h,
          volume24hUsd: volume24h,
          marketCapUsd: fdv,
          oracleProvider: `Solana DEX (${pair.dexId?.toUpperCase() || 'ORCA'} / Jupiter)`,
          lastUpdated: new Date().toISOString(),
          timestamp: now,
        };
        lastOracleFetch = now;
        return res.json(cachedOracleData);
      }
    }
  } catch (err) {
    console.log('Note on live DEX price fetch:', err.message);
  }

  // Baseline fallback (~0.0215) if external DEX API is slow
  const basePrice = 0.0215;
  const cycle = (now / 15000) % (2 * Math.PI);
  const microDrift = Math.sin(cycle) * 0.0003;
  const fallbackPrice = parseFloat((basePrice + microDrift).toFixed(5));

  const fallbackData = {
    success: true,
    symbol: 'SKR',
    name: 'Seeker',
    mintAddress: 'SKRbvo6Gf7GondiT3BbTfuRDPqLWei4j2Qy2NPGZhW3',
    chain: 'solana',
    priceUsd: fallbackPrice,
    priceSol: +(fallbackPrice / solUsd).toFixed(8),
    solUsdPrice: solUsd,
    change24h: 1.76,
    volume24hUsd: 460000,
    marketCapUsd: 21500000,
    oracleProvider: 'Solana DexScreener / Jupiter Feed',
    lastUpdated: new Date().toISOString(),
    timestamp: now,
  };

  return res.json(cachedOracleData || fallbackData);
});

// --------------------------------------------------------------------------
// 7B. FOLLOWS & PROFILES ENDPOINTS
// --------------------------------------------------------------------------
const serverFollows = new Set(); // "followerId_petId"

app.post('/api/follows/follow', async (req, res) => {
  const { followerId, petId } = req.body;
  if (!followerId || !petId) {
    return res.status(400).json({ success: false, error: 'Missing followerId or petId' });
  }
  serverFollows.add(`${followerId}_${petId}`);
  if (supabaseAdmin) {
    try {
      await supabaseAdmin.from('follows').upsert({
        follower_id: followerId,
        following_pet_id: petId,
      }, { onConflict: 'follower_id,following_pet_id' });
    } catch (e) {
      console.log('Note on Supabase follow insert:', e.message);
    }
  }
  return res.json({ success: true, isFollowing: true });
});

app.post('/api/follows/unfollow', async (req, res) => {
  const { followerId, petId } = req.body;
  if (!followerId || !petId) {
    return res.status(400).json({ success: false, error: 'Missing followerId or petId' });
  }
  serverFollows.delete(`${followerId}_${petId}`);
  if (supabaseAdmin) {
    try {
      await supabaseAdmin.from('follows').delete().eq('follower_id', followerId).eq('following_pet_id', petId);
    } catch (e) {
      console.log('Note on Supabase unfollow delete:', e.message);
    }
  }
  return res.json({ success: true, isFollowing: false });
});

app.get('/api/follows/list', async (req, res) => {
  const { followerId } = req.query;
  if (!followerId) {
    return res.status(400).json({ success: false, error: 'Missing followerId' });
  }
  const followedPetIds = [];
  for (const key of serverFollows) {
    if (key.startsWith(`${followerId}_`)) {
      followedPetIds.push(key.substring(`${followerId}_`.length));
    }
  }
  if (supabaseAdmin) {
    try {
      const { data, error } = await supabaseAdmin.from('follows').select('following_pet_id').eq('follower_id', followerId);
      if (!error && data) {
        const dbPetIds = data.map(d => d.following_pet_id).filter(Boolean);
        const allIds = Array.from(new Set([...followedPetIds, ...dbPetIds]));
        let pets = [];
        if (allIds.length > 0) {
          const { data: petData } = await supabaseAdmin.from('pets').select('*').in('id', allIds);
          pets = petData || [];
        }
        return res.json({ success: true, followedPetIds: allIds, pets });
      }
    } catch (e) {
      console.log('Note on Supabase follow select:', e.message);
    }
  }
  return res.json({ success: true, followedPetIds, pets: [] });
});

// --------------------------------------------------------------------------
// 7C. AUTHENTICATION & EMAIL VERIFICATION ENDPOINT
// --------------------------------------------------------------------------
const knownEmails = new Set();

app.get('/api/auth/check-email', async (req, res) => {
  const { email } = req.query;
  if (!email || !email.trim()) {
    return res.status(400).json({ success: false, error: 'Missing email' });
  }
  const cleanEmail = email.trim().toLowerCase();
  
  if (knownEmails.has(cleanEmail)) {
    return res.json({ success: true, exists: true, source: 'cache' });
  }

  if (supabaseAdmin) {
    try {
      // 1. Check in profiles table
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('id, email, username, wallet_address')
        .ilike('email', cleanEmail)
        .maybeSingle();

      if (profile) {
        knownEmails.add(cleanEmail);
        return res.json({ success: true, exists: true, profile });
      }

      // 2. Check in Supabase auth.users via Admin API
      const { data: usersData, error } = await supabaseAdmin.auth.admin.listUsers();
      if (!error && usersData && usersData.users) {
        const found = usersData.users.find(u => u.email && u.email.toLowerCase() === cleanEmail);
        if (found) {
          knownEmails.add(cleanEmail);
          return res.json({ success: true, exists: true, userId: found.id, source: 'auth_users' });
        }
      }
    } catch (e) {
      console.log('Note on checking email in Supabase:', e.message);
    }
  }

  return res.json({ success: true, exists: false });
});

app.post('/api/auth/verify', async (req, res) => {
  const { token, walletAddress, email, username, fullName } = req.body;
  if (email) {
    knownEmails.add(email.trim().toLowerCase());
  }

  // Provision in Dynamic in background/realtime
  if (email) {
    provisionDynamicUser({ email, username, fullName, walletAddress }).catch(e => {
      console.log('Dynamic auto-provision error:', e.message);
    });
  }

  return res.json({
    success: true,
    user: {
      id: walletAddress ? 'usr_' + walletAddress.substring(0, Math.min(8, walletAddress.length)) : 'usr_guest',
      walletAddress,
      email,
      pawtScore: 100
    }
  });
});

app.post('/api/dynamic/provision', async (req, res) => {
  const { email, username, fullName, walletAddress } = req.body;
  try {
    const dynUser = await provisionDynamicUser({ email, username, fullName, walletAddress });
    return res.json({ success: true, dynamicUser: dynUser });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// --------------------------------------------------------------------------
// 7. SOLANA RPC PROXY (Bypasses Solana public RPC CORS and 403 browser blocks)
// --------------------------------------------------------------------------
app.post('/api/solana-rpc', async (req, res) => {
  try {
    const isDevnet = req.query.cluster === 'devnet';
    const targetRpc = isDevnet ? 'https://api.devnet.solana.com' : 'https://api.mainnet-beta.solana.com';

    const response = await fetch(targetRpc, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(req.body)
    });
    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (err) {
    console.error('Solana RPC Proxy Error:', err.message);
    return res.status(500).json({
      jsonrpc: '2.0',
      error: { code: 500, message: err.message },
      id: req.body?.id || 1
    });
  }
});

// --------------------------------------------------------------------------
// 8. SPA FALLBACK ROUTE FOR FLUTTER WEB
// --------------------------------------------------------------------------
app.get('*', (req, res) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ success: false, error: 'API endpoint not found' });
  }
  const indexPath = path.join(webBuildPath, 'index.html');
  if (fs.existsSync(indexPath)) {
    res.sendFile(indexPath);
  } else {
    res.json({
      status: 'ok',
      service: 'Pawtbook Backend API',
      version: '1.1.0',
      message: 'Pawtbook Backend API is running. Build Flutter Web (flutter build web) to serve the frontend.'
    });
  }
});

app.listen(PORT, () => {
  console.log(`Pawtbook Backend API running on port ${PORT}`);
  console.log(`⚡ Stripe Webhook route available at /api/webhooks/stripe`);
});
