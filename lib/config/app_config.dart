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

  // Dynamic.xyz Auth Configuration
  static const String dynamicEnvironmentId = String.fromEnvironment(
    'DYNAMIC_ENVIRONMENT_ID',
    defaultValue: 'e84fa2357-6be3-4bc4-b90d-2082608d7889',
  );

  // App Identity
  static const String appName = 'Pawtbook';
  static const String appTagline = 'SocialFi for Pets on Solana';
}
