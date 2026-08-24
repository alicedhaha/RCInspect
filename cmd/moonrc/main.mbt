///|
extern "C" fn exit(code : Int) = "exit"

///|
async fn main {
  let argv = @env.args()
  let args : Array[String] = []
  for index in 1..<argv.length() {
    args.push(argv[index])
  }
  if args.length() == 0 ||
    args[0] == "-h" ||
    args[0] == "--help" ||
    args[0] == "help" {
    @stdio.stdout.write(@cli.usage())
    return
  }
  let config = match @cli.parse_config(args) {
    Ok(value) => value
    Err(message) => {
      @stdio.stderr.write(message)
      if !message.has_suffix("\n") {
        @stdio.stderr.write("\n")
      }
      exit(2)
      return
    }
  }
  let source = @fs.read_file(config.input).text() catch {
    _ => {
      @stdio.stderr.write("moonrc: cannot read '\{config.input}'\n")
      exit(2)
      return
    }
  }
  let outcome = @cli.execute(config, source)
  match config.output {
    Some(path) =>
      @fs.write_file(path, @utf8.encode(outcome.content)) catch {
        _ => {
          @stdio.stderr.write("moonrc: cannot write '\{path}'\n")
          exit(2)
          return
        }
      }
    None => @stdio.stdout.write(outcome.content)
  }
  if outcome.failed {
    @stdio.stderr.write("moonrc: command completed with diagnostics\n")
    exit(1)
  }
}
