class Faigrid < Formula
  desc "fusionAIze Grid — sovereign AI execution substrate for multi-node operations"
  homepage "https://github.com/fusionAIze/faigrid"
  url "https://github.com/fusionAIze/faigrid/archive/refs/tags/v1.6.2.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
  license "Apache-2.0"
  head "https://github.com/fusionAIze/faigrid.git", branch: "main"

  depends_on "bash"
  depends_on "rsync"
  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]

    # ── Shell entry points ─────────────────────────────────────────────────────
    (bin/"faigrid").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      exec "#{libexec}/install.sh" "$@"
    SH

    (bin/"faigrid-workbench").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      exec "#{libexec}/core/workbench/scripts/control.sh" "$@"
    SH

    # ── grid-messenger: Python venv + dependencies ─────────────────────────────
    venv = libexec/"messenger-venv"
    system python3, "-m", "venv", venv
    system venv/"bin/pip", "install", "--quiet",
           "python-telegram-bot>=20.0",
           "aiohttp>=3.9"

    # ── grid-messenger: entry point (sources user config) ─────────────────────
    (bin/"faigrid-messenger").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      CONFIG="${HOME}/.config/grid-messenger/config.env"
      if [[ -f "$CONFIG" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$CONFIG"
        set +a
      fi
      exec "#{venv}/bin/python3" \
        "#{libexec}/core/messenger/src/grid_messenger.py" "$@"
    SH
  end

  def post_install
    (var/"log/faigrid").mkpath
    # Ensure user config directory exists
    config_dir = Pathname.new("#{ENV["HOME"]}/.config/grid-messenger")
    config_dir.mkpath unless config_dir.exist?
  end

  # brew services start faigrid  →  starts grid-messenger
  service do
    run [opt_bin/"faigrid-messenger"]
    keep_alive true
    log_path var/"log/faigrid/messenger.log"
    error_log_path var/"log/faigrid/messenger.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    assert_predicate bin/"faigrid", :executable?
    assert_predicate bin/"faigrid-workbench", :executable?
    assert_predicate bin/"faigrid-messenger", :executable?
    assert_path_exists libexec/"install.sh"
    assert_path_exists libexec/"core/workbench/scripts/control.sh"
    assert_path_exists libexec/"core/messenger/src/grid_messenger.py"
    assert_path_exists libexec/"messenger-venv/bin/python3"
  end
end
