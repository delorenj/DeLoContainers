#!/bin/bash

# Ensure required arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 KEY_NAME KEY_VALUE [VAULT_NAME]"
    echo "Example: $0 OPENAI_API_KEY sk-123456 MyVault"
    exit 1
fi

KEY_NAME="$1"
KEY_VALUE="$2"
VAULT_NAME="${3:-DeLoSecrets}"  # Default to DeLoSecrets if no vault specified

# Create temporary template file
TEMPLATE_FILE=$(mktemp)
trap 'rm -f "$TEMPLATE_FILE"' EXIT  # Clean up temp file on script exit

# Create template JSON
cat > "$TEMPLATE_FILE" << EOF
{
  "title": "$KEY_NAME",
  "category": "API Credential",
  "fields": [
    {
      "id": "password",
      "type": "CONCEALED",
      "purpose": "PASSWORD",
      "label": "credential",
      "value": "$KEY_VALUE"
    }
  ]
}
EOF

# Delete existing item if it exists (suppress error if it doesn't)
op item delete "$KEY_NAME" --vault "$VAULT_NAME" 2>/dev/null || true

# Create new item
if op item create --vault "$VAULT_NAME" --template "$TEMPLATE_FILE"; then
    echo "✅ Successfully added $KEY_NAME to $VAULT_NAME vault"
    echo "To retrieve this value, use:"
    echo "op read \"op://$VAULT_NAME/$KEY_NAME/password\""
else
    echo "❌ Failed to add $KEY_NAME to $VAULT_NAME vault"
    exit 1
fi
