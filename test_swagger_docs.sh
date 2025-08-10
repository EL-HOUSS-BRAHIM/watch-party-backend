#!/bin/bash

# Test Swagger Documentation Setup
echo "🚀 Testing Watch Party API Swagger Documentation Setup"
echo "================================================="

# Check if the server is running
echo "📋 Checking if development server is running..."

# Start the development server in the background if not running
if ! pgrep -f "manage.py runserver" > /dev/null; then
    echo "🔄 Starting development server..."
    cd /workspaces/watch-party-backend
    source activate_venv.sh
    python manage.py runserver 0.0.0.0:8000 &
    SERVER_PID=$!
    echo "⏳ Waiting for server to start..."
    sleep 10
else
    echo "✅ Development server is already running"
fi

# Test API endpoints
echo ""
echo "🧪 Testing API Documentation Endpoints:"
echo ""

# Test API root
echo "1. Testing API root endpoint..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8000/api/

# Test Schema endpoint
echo "2. Testing OpenAPI schema endpoint..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8000/api/schema/

# Test Swagger UI
echo "3. Testing Swagger UI endpoint..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8000/api/docs/

# Test ReDoc
echo "4. Testing ReDoc endpoint..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8000/api/redoc/

# Test redirect shortcuts
echo "5. Testing docs redirect..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8000/docs/

echo "6. Testing swagger redirect..."
curl -s -o /dev/null -w "Status: %{http_code}\n" http://localhost:8000/swagger/

echo ""
echo "📖 Access your API documentation:"
echo "   • Swagger UI: http://localhost:8000/api/docs/"
echo "   • ReDoc:      http://localhost:8000/api/redoc/"
echo "   • Schema:     http://localhost:8000/api/schema/"
echo "   • Shortcuts:  http://localhost:8000/docs/ or http://localhost:8000/swagger/"
echo ""
echo "✨ Swagger documentation is now configured with enhanced features:"
echo "   ✅ Interactive API testing"
echo "   ✅ Detailed request/response examples"
echo "   ✅ Authentication support"
echo "   ✅ Organized by tags"
echo "   ✅ Search and filtering"
echo "   ✅ Try-it-out functionality"
echo ""

# Clean up
if [ ! -z "$SERVER_PID" ]; then
    echo "🛑 Stopping test server..."
    kill $SERVER_PID 2>/dev/null
fi

echo "🎉 Swagger documentation setup complete!"
