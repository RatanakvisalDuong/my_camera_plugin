#!/bin/bash

# Configuration
NEXUS_URL="http://localhost:8081"
NEXUS_USERNAME="admin"
NEXUS_PASSWORD="november"
REPOSITORY="flutter-plugin"

# Read package info from pubspec.yaml
PACKAGE_NAME=$(grep "^name:" pubspec.yaml | cut -d' ' -f2)
VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2)

echo "📦 Publishing $PACKAGE_NAME version $VERSION to Nexus..."

# Create clean directory structure
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"

# Copy plugin files (exclude unnecessary files)
echo "📁 Preparing package files..."
mkdir -p "$PACKAGE_DIR"
rsync -av --exclude='.git' \
          --exclude='build' \
          --exclude='.dart_tool' \
          --exclude='example/.dart_tool' \
          --exclude='example/build' \
          --exclude='example/ios/Runner.xcworkspace' \
          --exclude='example/ios/Runner.xcuserdata' \
          --exclude='example/android/.gradle' \
          --exclude='*.log' \
          --exclude='.DS_Store' \
          . "$PACKAGE_DIR/"

# Create tarball
echo "🗜️  Creating package archive..."
cd "$TEMP_DIR"
tar -czf "$PACKAGE_NAME-$VERSION.tar.gz" "$PACKAGE_NAME"

# Create package metadata JSON
cat > "$PACKAGE_NAME-$VERSION.json" << EOF
{
  "name": "$PACKAGE_NAME",
  "version": "$VERSION",
  "description": "$(grep "^description:" $PACKAGE_DIR/pubspec.yaml | cut -d':' -f2- | xargs)",
  "archive_url": "$NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/$VERSION/$PACKAGE_NAME-$VERSION.tar.gz",
  "pubspec_url": "$NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/$VERSION/pubspec.yaml",
  "published_at": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")"
}
EOF

# Upload package archive
echo "🚀 Uploading package archive..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
  --upload-file "$PACKAGE_NAME-$VERSION.tar.gz" \
  "$NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/$VERSION/$PACKAGE_NAME-$VERSION.tar.gz")

if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Failed to upload archive. HTTP Code: $HTTP_CODE"
    exit 1
fi

# Upload pubspec.yaml
echo "📄 Uploading pubspec.yaml..."
curl -s -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
  --upload-file "$PACKAGE_DIR/pubspec.yaml" \
  "$NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/$VERSION/pubspec.yaml"

# Upload package metadata
echo "📋 Uploading package metadata..."
curl -s -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
  --upload-file "$PACKAGE_NAME-$VERSION.json" \
  "$NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/$VERSION/package.json"

# Create/update package index
echo "📑 Updating package index..."
cat > "index.json" << EOF
{
  "name": "$PACKAGE_NAME",
  "versions": ["$VERSION"],
  "latest": "$VERSION",
  "repository_url": "$NEXUS_URL/repository/$REPOSITORY",
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")"
}
EOF

curl -s -u "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
  --upload-file "index.json" \
  "$NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/index.json"

# Cleanup
rm -rf "$TEMP_DIR"

echo "✅ Successfully published $PACKAGE_NAME $VERSION to Nexus!"
echo ""
echo "📍 Package URLs:"
echo "   Archive: $NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/$VERSION/$PACKAGE_NAME-$VERSION.tar.gz"
echo "   Metadata: $NEXUS_URL/repository/$REPOSITORY/$PACKAGE_NAME/$VERSION/package.json"
echo ""
echo "📝 To use this plugin, add to pubspec.yaml:"
echo "dependencies:"
echo "  $PACKAGE_NAME:"
echo "    git:"
echo "      url: https://github.com/yourorg/$PACKAGE_NAME.git"
echo "      ref: v$VERSION"
