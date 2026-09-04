// Lotería Nacional — dashboard de estado de datos.
//
// Existe porque hasta ahora este proceso se arrancó a mano y quedó con el cwd
// apuntando a la carpeta de otro proyecto, que no es la suya. Funcionaba de
// casualidad: Web/server.js:11 resuelve todo con path.resolve(__dirname, '..')
// y nunca lee process.cwd(). Con este archivo el arranque es reproducible.
//
// Arrancar desde PowerShell ELEVADA (el daemon de pm2 corre elevado):
//   pm2 delete prc-loteria-nacional-dashboard
//   cd "D:\PRC Loteria Nacional"; pm2 start ecosystem.config.js; pm2 save
//
// El pm2 save es imprescindible: la tarea de arranque de pm2 hace
// 'pm2 resurrect' al iniciar sesión y sin el save resucitaría el cwd viejo.

module.exports = {
  apps: [
    {
      name: 'prc-loteria-nacional-dashboard',
      script: 'Web/server.js',
      // __dirname y no la ruta fija: asi un renombrado de la carpeta no obliga
      // a editar este fichero.
      cwd: __dirname,
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '200M',
      env: {
        NODE_ENV: 'production',
        // Web/server.js:10 -> Number(process.env.LOTERIA_PORT) || 3020
        LOTERIA_PORT: 3020,
      },
    },
  ],
};
