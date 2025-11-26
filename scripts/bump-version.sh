#!/bin/bash
# Usage: ./bump-version.sh <package-name> <new-version>
# Example: ./bump-version.sh package patch
# Example: ./bump-version.sh package 1.2.3
# Example: ./bump-version.sh package major

set -e

PACKAGE="$1"

if [ -z "$PACKAGE" ]; then
  echo "Usage: $0 <package-name> <new-version>"
  exit 1
fi

TAG="$2"

if [ -n "$TAG" ]; then
  # Bump version in root package.json
  pnpm version --no-git-tag-version $@

  # Bump version in all workspaces
  pnpm -r exec pnpm version --no-git-tag-version $@

  # Get the new version from root package.json
  NEW_VERSION=$(node -p "require('./package.json').version")

  # Make sure all packages depend on latest versions of other packages

  echo "Updating all dependencies to version $NEW_VERSION"

  find . -name 'package.json' -not -path '*/node_modules/*' | while read -r pkg_file; do
    # Only update if there are dependencies
    if grep -q "\"$PACKAGE" "$pkg_file"; then
      tmp_file=$(mktemp)
      node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('$pkg_file', 'utf8'));
        const newVersion = '$NEW_VERSION';
        ['dependencies', 'devDependencies'].forEach(depType => {
          if (pkg[depType]) {
            Object.keys(pkg[depType]).forEach(dep => {
              if (dep.startsWith('$PACKAGE')) {
                const initialChar = pkg[depType][dep][0];
                if (['^', '~', '>', '<', '='].includes(initialChar)) {
                  pkg[depType][dep] = initialChar + newVersion;
                } else {
                  pkg[depType][dep] = newVersion;
                }
              }
            });
          }
        });
        fs.writeFileSync('$tmp_file', JSON.stringify(pkg, null, 2) + '\n');
      "
      mv "$tmp_file" "$pkg_file"
      echo "Updated $pkg_file"
    fi
  done

  echo "Version bump completed successfully to $NEW_VERSION"
fi

# Update lockfile
pnpm install --lockfile-only