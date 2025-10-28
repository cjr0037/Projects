#!/bin/bash
# Setup script for Master POI Table Creator

echo "=========================================="
echo "Master POI Table Creator - Setup"
echo "=========================================="
echo ""

# Create output directory
echo "Creating output directory..."
mkdir -p output

# Check Python version
echo "Checking Python version..."
python3 --version

# Create virtual environment (optional)
read -p "Create virtual environment? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Creating virtual environment..."
    python3 -m venv venv
    echo "Activating virtual environment..."
    source venv/bin/activate
fi

# Install dependencies
echo ""
echo "Installing Python dependencies..."
pip install -r requirements.txt

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run the example: python create_master_poi_table.py"
echo "  2. Or run examples: python example_usage.py"
echo "  3. For database setup, run: psql database_name < poi_schema.sql"
echo ""