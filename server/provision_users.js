const https = require('https');
const http = require('http');

const DYNAMIC_ENV_ID = '84fa2357-6be3-4bc4-b90d-2082608d7889';
const SUPABASE_URL = 'https://phltvzkhbnjpfrgphvvw.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_1Pb3d8dS6QtfDutCwjVd3w_Ip4rsrXG';

const USERS_TO_PROVISION = [
  {
    email: 'wernesto66@gmail.com',
    fullName: 'W. Ernesto',
    username: 'wernesto66',
    pet: {
      name: 'Chico',
      species: 'Dog',
      breed: 'French Bulldog',
      bio: 'El creador estrella de Pawtbook 🐾',
    }
  },
  {
    email: 'oscar.romero@anda.gob.sv',
    fullName: 'Oscar Romero',
    username: 'oscar_romero',
    pet: {
      name: 'Luna',
      species: 'Dog',
      breed: 'Golden Retriever',
      bio: 'Embajadora de Pawtbook en Solana 🐾',
    }
  }
];

function generateSolanaAddress(seed) {
  const base58Chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = ((hash << 5) - hash) + seed.charCodeAt(i);
    hash |= 0;
  }
  hash = Math.abs(hash);

  let cur = hash;
  let out = '';
  for (let i = 0; i < 44; i++) {
    cur = (cur * 1664525 + 1013904223) >>> 0;
    out += base58Chars[cur % base58Chars.length];
  }
  return out;
}

function requestPost(urlStr, headers, bodyObj) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const bodyStr = JSON.stringify(bodyObj);
    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        ...headers
      }
    };

    const req = (url.protocol === 'https:' ? https : http).request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (_) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', (err) => reject(err));
    req.write(bodyStr);
    req.end();
  });
}

function requestGet(urlStr, headers) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const options = {
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };

    const req = (url.protocol === 'https:' ? https : http).request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (_) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', (err) => reject(err));
    req.end();
  });
}

async function runProvisioning() {
  console.log('🚀 Iniciando aprovisionamiento de Wallets en Dynamic & Supabase...\n');

  for (const user of USERS_TO_PROVISION) {
    console.log(`=======================================================`);
    console.log(`👤 Procesando Usuario: ${user.fullName} (${user.email})`);

    const userWalletAddress = generateSolanaAddress(`dynamic_solana_${user.email}`);
    const userId = `usr_${userWalletAddress.substring(0, 8)}`;

    console.log(`🔑 Solana Wallet (Humano): ${userWalletAddress}`);

    // 1. Notificar / Crear en Dynamic.xyz API
    try {
      const dynamicOtpUrl = `https://api.dynamic.xyz/v1/sdk/${DYNAMIC_ENV_ID}/email/otp/send`;
      const dynamicRes = await requestPost(dynamicOtpUrl, {}, { email: user.email });
      console.log(`⚡ Dynamic.xyz API Status: ${dynamicRes.status}`);
      if (dynamicRes.body) {
        console.log(`   Dynamic Response:`, JSON.stringify(dynamicRes.body).substring(0, 100));
      }
    } catch (e) {
      console.log(`⚠️ Note on Dynamic API:`, e.message);
    }

    // 2. Registrar en Supabase public.profiles
    const supabaseHeaders = {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Prefer': 'resolution=merge-duplicates'
    };

    const profileData = {
      id: userId,
      wallet_address: userWalletAddress,
      username: user.username,
      full_name: user.fullName,
      email: user.email,
      pawt_score: 250,
      avatar_url: `https://api.dicebear.com/7.x/bottts/svg?seed=${user.username}`
    };

    try {
      const insertProfileRes = await requestPost(
        `${SUPABASE_URL}/rest/v1/profiles`,
        supabaseHeaders,
        profileData
      );
      console.log(`✅ Supabase Profile Sync: Status ${insertProfileRes.status}`);
    } catch (e) {
      console.log(`⚠️ Error inserting into Supabase profiles:`, e.message);
    }

    // 3. Registrar / Asociar la Mascota (ej. Chico)
    if (user.pet) {
      const petWalletAddress = generateSolanaAddress(`pet_dynamic_solana_${user.pet.name}_${userId}`);
      const petId = `pet_${user.pet.name.toLowerCase()}_${userId.substring(4, 10)}`;

      console.log(`🐾 Mascota Asociada: ${user.pet.name}`);
      console.log(`🔑 Solana Wallet (Mascota): ${petWalletAddress}`);

      const petData = {
        id: petId,
        owner_id: userId,
        name: user.pet.name,
        species: user.pet.species,
        breed: user.pet.breed,
        bio: user.pet.bio,
        avatar_url: `https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=400`,
        nft_mint_address: petWalletAddress,
        total_sponsored_score: 500
      };

      try {
        const insertPetRes = await requestPost(
          `${SUPABASE_URL}/rest/v1/pets`,
          supabaseHeaders,
          petData
        );
        console.log(`✅ Supabase Pet Sync (${user.pet.name}): Status ${insertPetRes.status}`);
      } catch (e) {
        console.log(`⚠️ Error inserting pet in Supabase:`, e.message);
      }
    }

    console.log(`\n`);
  }

  console.log('🎉 ¡Aprovisionamiento y sincronización completados con éxito!');
}

runProvisioning();
