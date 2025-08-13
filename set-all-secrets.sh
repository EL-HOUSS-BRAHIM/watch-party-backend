#!/bin/bash

# Script to set all GitHub secrets from .env file
# This reads your working .env and sets each variable as a GitHub secret

set -e

echo "🔐 Setting GitHub secrets from .env file..."

# Read the .env file and set each variable as a secret
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip empty lines and comments
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    
    # Remove any leading/trailing whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    # Skip if key or value is empty
    [[ -z "$key" || -z "$value" ]] && continue
    
    # Set the secret
    echo "Setting: $key"
    if gh secret set "$key" --body "$value" 2>/dev/null; then
        echo "✅ Successfully set: $key"
    else
        echo "❌ Failed to set: $key"
    fi
    
    # Small delay to avoid rate limits
    sleep 0.5
    
done < .env

echo ""
echo "🎉 Finished setting GitHub secrets!"
echo ""
echo "📋 To verify secrets were set, run:"
echo "   gh secret list"
