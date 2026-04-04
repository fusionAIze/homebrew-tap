class Faisignal < Formula
  desc "Observability, monitoring and signal layer for the fusionAIze stack"
  homepage "https://github.com/fusionAIze/faisignal"
  url "https://github.com/fusionAIze/faisignal/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "f328fcfe1b71842c50d97a47c3227b88d20bc4e68deb8f45f12370ba92369ffa"
  license "Apache-2.0"
  head "https://github.com/fusionAIze/faisignal.git", branch: "main"

  depends_on "python@3.12"

  def install
    python = Formula["python@3.12"].opt_bin/"python3.12"

    # Build native Python extensions from source with extra Mach-O header
    # space so Homebrew's linkage fixups do not trip over vendored wheels.
    ENV["PIP_NO_BINARY"] = "pydantic-core,watchfiles"
    ENV.append "RUSTFLAGS", " -C link-arg=-Wl,-headerpad_max_install_names"
    ENV.append "LDFLAGS", " -Wl,-headerpad_max_install_names"

    system python, "-m", "venv", libexec
    system libexec/"bin/pip", "install", "--upgrade", "pip", "setuptools", "wheel"
    system libexec/"bin/pip", "install", buildpath

    pkgshare.install buildpath.children

    # Main service entry point
    (bin/"faisignal").write <<~SH
      #!/bin/bash
      set -euo pipefail
      mkdir -p "#{etc}/faisignal" "#{var}/lib/faisignal" "#{var}/log/faisignal"
      export FAISIGNAL_DB_PATH="${FAISIGNAL_DB_PATH:-#{var}/lib/faisignal/faisignal.db}"
      cd "#{etc}/faisignal"
      exec "#{libexec}/bin/python" -m faisignal "$@"
    SH

    # CLI tool
    (bin/"faisignal-cli").write <<~SH
      #!/bin/bash
      set -euo pipefail
      mkdir -p "#{etc}/faisignal" "#{var}/lib/faisignal"
      export FAISIGNAL_DB_PATH="${FAISIGNAL_DB_PATH:-#{var}/lib/faisignal/faisignal.db}"
      cd "#{etc}/faisignal"
      exec "#{libexec}/bin/faisignal-cli" "$@"
    SH
  end

  def post_install
    (etc/"faisignal").mkpath
    (var/"lib/faisignal").mkpath
    (var/"log/faisignal").mkpath
  end

  service do
    run [opt_bin/"faisignal"]
    working_dir etc/"faisignal"
    environment_variables(
      FAISIGNAL_DB_PATH: var/"lib/faisignal/faisignal.db",
    )
    keep_alive true
    log_path var/"log/faisignal/output.log"
    error_log_path var/"log/faisignal/error.log"
  end

  test do
    assert_match "fusionAIze Signal v0.1.0", shell_output("#{bin}/faisignal --version")
    assert_match "fusionAIze Signal v0.1.0", shell_output("#{bin}/faisignal-cli --version")
  end
end