class Faigrid < Formula
  desc "fusionAIze Grid — AI infrastructure orchestrator for multi-node setups"
  homepage "https://github.com/fusionAIze/faigrid"
  url "https://github.com/fusionAIze/faigrid/archive/refs/tags/v1.6.0.tar.gz"
  sha256 "47a85429d36f878d330ba0867137187d824ed015560c3bd991ad2797da7f084c"
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
    assert_predicate libexec/"install.sh", :exist?
    assert_predicate libexec/"core/workbench/scripts/control.sh", :exist?
  end
end
