class AppConfig {
  static const String r2MediaDomain = 'https://media.pawbooklife.com';
  static const String r2BucketName = 'pawtbook-media';
  
  // Real Supabase Configuration (Pawtbook Project: phltvzkhbnjpfrgphvvw)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://phltvzkhbnjpfrgphvvw.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_1Pb3d8dS6QtfDutCwjVd3w_Ip4rsrXG',
  );

  // Render.com Express Backend Service API
  static const String backendApiUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'https://pawbook-358b.onrender.com',
  );

  // App Identity
  static const String appName = 'Pawtbook';
  static const String appTagline = 'SocialFi for Pets on Solana';
}
