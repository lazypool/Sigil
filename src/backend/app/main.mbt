///|
async fn main {
  @proton.asset("Sigil", "src/frontend/dist/index.html", width=1180, height=760)
  ..config(@proton.load_config())
  ..single_instance()
  .run_or_abort()
}
