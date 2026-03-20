#!/usr/bin/env bash
set -euo pipefail

# Collect tree entries: apps[repo]="branch1 branch2 ..."
declare -A apps

for js_file in webapps/*/*/*.js; do
  [ -f "$js_file" ] || continue
  dir=$(dirname "$js_file")
  js_name=$(basename "$js_file")
  repo=$(echo "$dir" | cut -d/ -f2)
  branch=$(echo "$dir" | cut -d/ -f3)

  apps["$repo"]+="${apps[$repo]:+ }$branch"

  # Generate per-app index.html
  cat > "$dir/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${repo}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { width: 100vw; height: 100vh; overflow: hidden; background: #0d0d0d; }
    canvas { display: block; }
  </style>
</head>
<body>
  <script type="module">
    import init from './${js_name}';
    await init();
  </script>
</body>
</html>
EOF

  echo "Generated $dir/index.html (entry: $js_name)"
done

# Build JS object literal for the tree
tree_entries=""
for repo in $(echo "${!apps[@]}" | tr ' ' '\n' | sort); do
  branches=""
  for b in $(echo "${apps[$repo]}" | tr ' ' '\n' | sort); do
    branches+="${branches:+, }'$b'"
  done
  tree_entries+="${tree_entries:+,
      }$repo: [$branches]"
done

# Generate root index.html
cat > index.html <<'HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WASM Apps</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #0d0d0d;
      color: #c8c8c8;
      font-family: 'Courier New', Courier, monospace;
      font-size: 15px;
      padding: 32px;
      min-height: 100vh;
    }

    h1 {
      color: #e0e0e0;
      font-size: 18px;
      font-weight: normal;
      margin-bottom: 24px;
    }

    .tree {
      list-style: none;
      padding-left: 0;
    }

    .tree ul {
      list-style: none;
      padding-left: 20px;
    }

    .tree li {
      position: relative;
      padding: 2px 0;
    }

    .tree li::before {
      content: '';
      position: absolute;
      left: -14px;
      top: 0;
      width: 1px;
      height: 100%;
      background: #333;
    }

    .tree li::after {
      content: '';
      position: absolute;
      left: -14px;
      top: 11px;
      width: 10px;
      height: 1px;
      background: #333;
    }

    .tree li:last-child::before {
      height: 11px;
    }

    .tree > li::before,
    .tree > li::after {
      display: none;
    }

    .repo {
      color: #6a9fb5;
      cursor: pointer;
      user-select: none;
    }

    .repo::before {
      content: '\25BE ';
      color: #555;
    }

    .repo.collapsed::before {
      content: '\25B8 ';
    }

    .repo.collapsed + ul {
      display: none;
    }

    .branch a {
      color: #a3be8c;
      text-decoration: none;
    }

    .branch a:hover {
      color: #d0e8c0;
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <h1>webapps/</h1>
  <ul class="tree" id="tree"></ul>

  <script>
HEADER

cat >> index.html <<EOF
    const apps = {
      ${tree_entries}
    };
EOF

cat >> index.html <<'FOOTER'

    const tree = document.getElementById('tree');

    for (const [repo, branches] of Object.entries(apps)) {
      const repoLi = document.createElement('li');

      const repoSpan = document.createElement('span');
      repoSpan.className = 'repo';
      repoSpan.textContent = repo + '/';
      repoSpan.addEventListener('click', () => {
        repoSpan.classList.toggle('collapsed');
      });
      repoLi.appendChild(repoSpan);

      const branchUl = document.createElement('ul');
      for (const branch of branches) {
        const branchLi = document.createElement('li');
        branchLi.className = 'branch';
        const a = document.createElement('a');
        a.href = `/webapps/${repo}/${branch}/`;
        a.textContent = branch;
        branchLi.appendChild(a);
        branchUl.appendChild(branchLi);
      }
      repoLi.appendChild(branchUl);
      tree.appendChild(repoLi);
    }
  </script>
</body>
</html>
FOOTER

echo "Generated index.html"
