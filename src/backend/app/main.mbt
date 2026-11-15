///|
async fn main {
  let app = @proton.asset(
    "Sigil",
    "src/frontend/dist/index.html",
    width=1180,
    height=760,
  )
  app.config(@proton.load_config())
  app.single_instance()
  let config_path = mail_config_path(app)
  app.commands(fn(registrar) raise {
    registrar.bind(get_mail_settings_command, async fn(_context, request) {
      get_mail_settings(config_path, request)
    })
    registrar.bind(save_mail_settings_command, async fn(_context, request) {
      save_mail_settings(config_path, request)
    })
    registrar.bind(test_mail_settings_command, async fn(_context, request) {
      test_mail_settings(config_path, request)
    })
    registrar.bind(send_email_command, async fn(_context, request) {
      send_email(config_path, request)
    })
  })
  app.run_or_abort()
}
