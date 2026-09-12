class Faigate < Formula
  desc "Local OpenAI-compatible AI gateway for OpenClaw and other AI-native clients"
  homepage "https://github.com/fusionAIze/faigate"
  url "https://github.com/fusionAIze/faigate/archive/refs/tags/v2.8.1.tar.gz"
  sha256 "6d50b0a1f0b866ad88a73ba1d9be4061d87cfa040605ac4fef12e91988fc8f45"
  license "Apache-2.0"
  head "https://github.com/fusionAIze/faigate.git", branch: "main"

  depends_on "python@3.12"

  def install
    python = Formula["python@3.12"].opt_bin/"python3.12"

    # Keep the headerpad flags for any extension we _do_ end up building from
    # source, but prefer wheels whenever PyPI offers them. Without this,
    # `brew upgrade faigate` spent 3–5 minutes compiling pydantic-core from
    # source on every run. Wheels for pydantic-core ship with sufficient
    # headerpad space and pass Homebrew's linkage audit out of the box.
    ENV.append "LDFLAGS", " -Wl,-headerpad_max_install_names"

    system python, "-m", "venv", libexec
    system libexec/"bin/pip", "install", "--upgrade", "pip", "setuptools", "wheel"
    system libexec/"bin/pip", "install", "--prefer-binary", buildpath

    pkgshare.install buildpath.children

    (bin/"faigate").write <<~SH
      #!/bin/bash
      set -euo pipefail
      mkdir -p "#{etc}/faigate" "#{var}/lib/faigate"
      export FAIGATE_CONFIG_FILE="${FAIGATE_CONFIG_FILE:-#{etc}/faigate/config.yaml}"
      export FAIGATE_DB_PATH="${FAIGATE_DB_PATH:-#{var}/lib/faigate/faigate.db}"
      cd "#{etc}/faigate"
      exec "#{libexec}/bin/python" -m faigate "$@"
    SH

    (bin/"faigate-stats").write <<~SH
      #!/bin/bash
      set -euo pipefail
      export FAIGATE_CONFIG_FILE="${FAIGATE_CONFIG_FILE:-#{etc}/faigate/config.yaml}"
      export FAIGATE_DB_PATH="${FAIGATE_DB_PATH:-#{var}/lib/faigate/faigate.db}"
      cd "#{etc}/faigate"
      exec "#{libexec}/bin/faigate-stats" "$@"
    SH

    %w[
      faigate-menu
      faigate-dashboard
      faigate-api-keys
      faigate-auto-update
      faigate-provider-probe
      faigate-provider-setup
      faigate-config-overview
      faigate-config-wizard
      faigate-client-integrations
      faigate-client-scenarios
      faigate-logs
      faigate-restart
      faigate-routing-settings
      faigate-server-settings
      faigate-start
      faigate-status
      faigate-stop
      faigate-doctor
      faigate-health
      faigate-onboarding-report
      faigate-onboarding-validate
      faigate-provider-discovery
      faigate-update
      faigate-update-check
    ].each do |helper|
      (bin/helper).write <<~SH
        #!/bin/bash
        set -euo pipefail
        mkdir -p "#{etc}/faigate" "#{var}/lib/faigate"
        export FAIGATE_CONFIG_FILE="${FAIGATE_CONFIG_FILE:-#{etc}/faigate/config.yaml}"
        export FAIGATE_ENV_FILE="${FAIGATE_ENV_FILE:-#{etc}/faigate/faigate.env}"
        export FAIGATE_DB_PATH="${FAIGATE_DB_PATH:-#{var}/lib/faigate/faigate.db}"
        export FAIGATE_PYTHON="#{libexec}/bin/python"
        exec "#{pkgshare}/scripts/#{helper}" "$@"
      SH
    end
  end

  def post_install
    # Homebrew rewrites library paths in installed binaries AFTER `install`
    # returns, which invalidates the ad-hoc signature wheel-shipped extensions
    # carry. On Apple Silicon macOS then refuses to map the modified page: the
    # process is SIGKILLed during dlopen with CODESIGNING / Invalid Page and
    # emits no traceback, so it reads as a crash with no cause. Signing inside
    # `install` is too early — it runs before the rewriting — which is why this
    # lives here. Seen on the 2.8.0 upgrade: pydantic_core and uvloop.
    if OS.mac?
      Dir.glob("#{libexec}/lib/python*/site-packages/**/*.{so,dylib}").each do |lib|
        next if quiet_system "/usr/bin/codesign", "--verify", lib

        system "/usr/bin/codesign", "--force", "--sign", "-", lib
      end
    end

    (etc/"faigate").mkpath
    (var/"lib/faigate").mkpath
    (var/"log/faigate").mkpath

    config_path = etc/"faigate/config.yaml"
    env_path = etc/"faigate/faigate.env"

    config_path.write((pkgshare/"config.yaml").read) unless config_path.exist?
    env_path.write((pkgshare/".env.example").read) unless env_path.exist?
  end

  service do
    run [opt_bin/"faigate"]
    working_dir etc/"faigate"
    environment_variables(
      FAIGATE_CONFIG_FILE: etc/"faigate/config.yaml",
      FAIGATE_DB_PATH:     var/"lib/faigate/faigate.db",
    )
    keep_alive true
    log_path var/"log/faigate/output.log"
    error_log_path var/"log/faigate/error.log"
  end

  test do
    assert_match "faigate #{version}", shell_output("#{bin}/faigate --version")
  end
end
