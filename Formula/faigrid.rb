class Faigrid < Formula
  desc "FusionAIze Grid — AI infrastructure orchestrator for multi-node setups"
  homepage "https://github.com/fusionAIze/faigrid"
  url "https://github.com/fusionAIze/faigrid/archive/refs/tags/v1.6.1.tar.gz"
  sha256 "772944bce5285ed298c7d166b99178fdbc2ac6eb1985d6bea9ed25c4eb8f01d1"
  license "Apache-2.0"
  head "https://github.com/fusionAIze/faigrid.git", branch: "main"

  depends_on "bash"
  depends_on "rsync"

  def install
    libexec.install Dir["*"]

    (bin/"faigrid").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      exec "#{libexec}/install.sh" "$@"
    SH

    # Expose workbench control directly
    (bin/"faigrid-workbench").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      exec "#{libexec}/core/workbench/scripts/control.sh" "$@"
    SH
  end

  def post_install
    (var/"log/faigrid").mkpath
  end

  test do
    assert_predicate bin/"faigrid", :executable?
    assert_path_exists libexec/"install.sh"
    assert_path_exists libexec/"core/workbench/scripts/control.sh"
  end
end
