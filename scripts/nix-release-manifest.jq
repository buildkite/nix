split("\n") | map([scan("\\S+")]) as $entries
| {
    version: $version,
    sha256: (
      reduce ("linux-amd64", "linux-arm64", "darwin-arm64") as $platform ({};
        "buildkite-agent-\($platform)-\($version).tar.gz" as $filename
        | [$entries[] | select(.[1] == $filename)] as $matches
        | if ($matches | length) == 1 and ($matches[0] | length) == 2
             and ($matches[0][0] | test("^[0-9a-f]{64}$"))
          then .[$platform] = $matches[0][0]
          else error("Expected exactly one SHA-256 checksum for \($filename)")
          end
      )
    )
  }
