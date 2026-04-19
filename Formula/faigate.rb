class Faigate < Formula
  desc "Local OpenAI-compatible AI gateway for OpenClaw and other AI-native clients"
  homepage "https://github.com/fusionAIze/faigate"
  url "https://github.com/fusionAIze/faigate/archive/refs/tags/v2.3.0.tar.gz"
  sha256 "0cedffbdbbeb5914be787a140ccf87afc48100068a5b3997ff04c92f4cba236b"
  license "Apache-2.0"
  head "https://github.com/fusionAIze/faigate.git", branch: "main"

  depends_on "rust" => :build
  depends_on "python@3.12"

  def install
    python = Formula["python@3.12"].opt_bin/"python3.12"

    # macOS packaging guard — DO NOT REMOVE.
    #
    # The previous "prefer wheels for everything" path silently regressed the
    # v1.2.2 hardening. Prebuilt pydantic-core / watchfiles wheels are linked
    # upstream without extra Mach-O headerpad space, so Homebrew's post-install
    # `install_name_tool -id` rewrite then fails with:
    #   "Failed changing dylib ID of ... pydantic_core/_pydantic_core.cpython-
    #    312-darwin.so ... Updated load commands do not fit in the header ...
    #    needs to be relinked, possibly with -headerpad_max_install_names"
    # `brew upgrade fusionaize/tap/faigate` printed that on every install in
    # v2.3.0. The runtime happened to keep working, which masked it.
    #
    # The fix is to force a source build of those two packages with the
    # headerpad linker flag. The 3-5 min cargo cost is the price of a clean
    # linkage audit. Do not switch back to `--prefer-binary` until pydantic-core
    # upstream ships wheels with sufficient headerpad. See:
    # https://github.com/fusionAIze/faigate/blob/main/docs/PUBLISHING.md#macos-packaging-guard
    ENV["PIP_NO_BINARY"] = "pydantic-core,watchfiles"
    ENV.append "RUSTFLAGS", " -C link-arg=-Wl,-headerpad_max_install_names"
    ENV.append "LDFLAGS", " -Wl,-headerpad_max_install_names"

    system python, "-m", "venv", libexec
    system libexec/"bin/pip", "install", "--upgrade", "pip", "setuptools", "wheel"
    # NB: no `--prefer-binary` — it would override PIP_NO_BINARY for the two
    # packages that actually need source builds.
    system libexec/"bin/pip", "install", buildpath

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
