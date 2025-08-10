# TMDB-to-Medusa: Import Script Guide

## Project Overview
**TMDB-to-Medusa** is a Python script that automatically imports your TheMovieDB (TMDB) lists into Medusa TV show manager. The script fetches shows from your TMDB lists and adds them to Medusa using their respective APIs, bridging the gap between TMDB's comprehensive TV show data and Medusa's automatic downloading capabilities.

## Prerequisites

### Required Accounts & API Keys
1. **TMDB Account & API Key**
   - Create account at [themoviedb.org](https://www.themoviedb.org)
   - Generate API key at [TMDB API Settings](https://www.themoviedb.org/settings/api)
   - Note your TMDB username/account ID

2. **Medusa Installation**
   - Running Medusa instance (accessible via web interface)
   - Medusa API key (found in Settings → Web Interface → API Key)

### Required Python Libraries
```bash
pip install requests python-dotenv
```

## Docker Development & Deployment

This project is designed to be developed, tested, and run in a Docker container for consistency across environments and easier deployment. The development environment is configured with hot-reloading, so any changes you make to the source code will be immediately reflected in the running container.

### Key Development Features

- **Hot Reloading**: Code changes are automatically detected and reloaded
- **Volume Mounts**: Local files are synced with the container in real-time
- **Development Tools**: Pre-configured with debugging and testing tools
- **Isolated Environment**: All dependencies are containerized

### Prerequisites

- Docker 20.10.0 or higher
- Docker Compose 2.0.0 or higher

### Development Setup

1. **Build the development container**
   ```bash
   docker-compose -f docker-compose.dev.yml build
   ```

2. **Start the development environment with hot-reloading**
   ```bash
   # This starts the development server with auto-reload enabled
   docker-compose -f docker-compose.dev.yml up -d
   ```

3. **Access the container**
   ```bash
   # Get a shell in the running container
   docker-compose -f docker-compose.dev.yml exec app bash
   ```

4. **Run the script with hot-reloading**
   ```bash
   # For development with auto-reload (restarts on file changes)
   python -m uvicorn --reload --host 0.0.0.0 --port 8000 tmdb_to_medusa:app
   ```
   
   Or for a simple script:
   ```bash
   # Install watchdog for file watching
   pip install watchdog
   
   # Run with auto-reload
   watchmedo auto-restart --directory=./ --pattern="*.py" --recursive -- python tmdb_to_medusa.py
   ```

5. **Making Changes**
   - Edit files in your local editor
   - The application will automatically reload when you save changes
   - Check logs with: `docker-compose -f docker-compose.dev.yml logs -f`

### Production Deployment

1. **Build the production image**
   ```bash
   docker build -t tmdb-to-medusa:latest .
   ```

2. **Run the container**
   ```bash
   docker run --rm --env-file .env tmdb-to-medusa:latest
   ```

### Docker Compose for Production

For production, use the provided `docker-compose.yml`:

```yaml
version: '3.8'

services:
  tmdb-to-medusa:
    build: .
    env_file: .env
    restart: unless-stopped
    volumes:
      - ./logs:/app/logs
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### Environment Variables

Create a `.env` file in the project root with the following variables:

```env
# TMDB Configuration
TMDB_API_KEY=your_tmdb_api_key
TMDB_USERNAME=your_tmdb_username
TMDB_ACCOUNT_ID=your_tmdb_account_id

# Medusa Configuration
MEDUSA_URL=http://medusa:8081
MEDUSA_API_KEY=your_medusa_api_key

# Application Settings
LOG_LEVEL=INFO
DRY_RUN=false
QUALITY_PROFILE_ID=1
ROOT_FOLDER=/tv/
```

### Volume Mounts

- `/app/logs`: Directory for application logs
- `/app/.cache`: Cached TMDB data (optional)

### Health Checks

The container includes a health check that verifies both TMDB and Medusa API connectivity:

```bash
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import requests; \
  requests.get('https://api.themoviedb.org/3/configuration?api_key=$TMDB_API_KEY').raise_for_status(); \
  requests.get('$MEDUSA_URL/api/v2/system/status', headers={'X-API-KEY': '$MEDUSA_API_KEY'}).raise_for_status()" || exit 1
```

## TMDB-to-Medusa Script Architecture

### Core Components
The TMDB-to-Medusa script needs to perform these main tasks:

1. **Authentication & Configuration**
   - TMDB API authentication
   - Medusa API authentication
   - Environment variable management

2. **TMDB List Fetching**
   - Retrieve user's TMDB lists
   - Extract TV show data from lists
   - Handle pagination for large lists

3. **Show Data Processing**
   - Convert TMDB show data to Medusa format
   - Map TMDB IDs to TVDB IDs (Medusa's primary indexer)
   - Handle show metadata (title, year, overview, etc.)

4. **Medusa Integration**
   - Check if show already exists in Medusa
   - Add new shows via Medusa API
   - Set monitoring preferences
   - Configure quality profiles

5. **Error Handling & Logging**
   - API rate limiting compliance
   - Network error handling
   - Duplicate show detection
   - Comprehensive logging

## Environment Configuration

Create a `.env` file for secure credential storage:

```env
# TMDB Configuration
TMDB_API_KEY=your_tmdb_api_key_here
TMDB_USERNAME=your_tmdb_username
TMDB_ACCOUNT_ID=your_tmdb_account_id

# Medusa Configuration
MEDUSA_URL=http://your-truenas-ip:port
MEDUSA_API_KEY=your_medusa_api_key

# TMDB-to-Medusa Script Configuration
DRY_RUN=false
LOG_LEVEL=INFO
QUALITY_PROFILE_ID=1
ROOT_FOLDER=/path/to/tv/shows/
PROJECT_NAME=TMDB-to-Medusa
```

## API Endpoints Reference

### TMDB API Endpoints
```
# Get Account Lists
GET https://api.themoviedb.org/3/account/{account_id}/lists

# Get List Details
GET https://api.themoviedb.org/3/list/{list_id}

# Get TV Show Details
GET https://api.themoviedb.org/3/tv/{tv_id}

# Get External IDs (to find TVDB ID)
GET https://api.themoviedb.org/3/tv/{tv_id}/external_ids
```

### Medusa API Endpoints
```
# Get Shows List
GET {medusa_url}/api/v2/shows

# Add New Show
POST {medusa_url}/api/v2/shows

# Get Show Details
GET {medusa_url}/api/v2/shows/{tvdb_id}

# Search for Show
GET {medusa_url}/api/v2/shows/search?q={query}
```

## TMDB-to-Medusa Script Structure

### 1. Configuration & Setup
```python
import os
import requests
import time
import logging
from dotenv import load_dotenv

class TMDBToMedusaImporter:
    def __init__(self):
        load_dotenv()
        self.setup_logging()
        self.load_config()
        self.setup_sessions()
        self.project_name = "TMDB-to-Medusa"

    def setup_logging(self):
        logging.basicConfig(
            level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
            format='%(asctime)s - TMDB-to-Medusa - %(levelname)s - %(message)s'
        )
```

### 2. TMDB Integration
```python
def get_tmdb_lists(self):
    """Fetch all lists for the authenticated user"""

def get_list_items(self, list_id):
    """Get all TV shows from a specific TMDB list"""

def get_show_details(self, tmdb_id):
    """Get detailed show information including external IDs"""

def get_tvdb_id(self, tmdb_id):
    """Convert TMDB ID to TVDB ID using external_ids endpoint"""
```

### 3. Medusa Integration
```python
def check_show_exists(self, tvdb_id):
    """Check if show already exists in Medusa"""

def add_show_to_medusa(self, show_data):
    """Add a new show to Medusa with proper configuration"""

def search_medusa_show(self, query):
    """Search for show in Medusa's database"""
```

### 4. Main Processing Logic
```python
def process_tmdb_list(self, list_id):
    """Process a single TMDB list"""

def import_all_lists(self):
    """Import all user's TMDB lists"""

def main(self):
    """Main execution function for TMDB-to-Medusa"""
```

## Data Mapping Requirements

### Show Data Structure
The TMDB-to-Medusa script must map TMDB data to Medusa's expected format:

```python
medusa_show_data = {
    "tvdb_id": tvdb_id,          # Required - from TMDB external_ids
    "title": tmdb_show["name"],  # Show title
    "year": release_year,        # Extract from first_air_date
    "overview": tmdb_show["overview"],
    "genre": genres_string,
    "language": tmdb_show["original_language"],
    "network": network_name,
    "status": tmdb_show["status"],
    "root_dir": root_folder_path,
    "quality_profile": quality_profile_id,
    "monitor": "all",            # or "pilot", "first", "latest"
    "search": True,              # Start searching immediately
    "subtitles": False,
    "imported_by": "TMDB-to-Medusa"  # Track import source
}
```

## Error Handling Strategies

### Rate Limiting
- TMDB: 40 requests per 10 seconds
- Medusa: No official limit, but be conservative
- Implement exponential backoff

### Common Issues & Solutions
1. **TVDB ID Not Found**
   - Try alternative search methods
   - Use show title search in Medusa
   - Log shows that couldn't be matched

2. **Show Already Exists**
   - Skip with info log
   - Optionally update monitoring settings

3. **Network Errors**
   - Retry with exponential backoff
   - Save progress to resume later

4. **Invalid Show Data**
   - Validate required fields
   - Skip malformed entries
   - Detailed error logging

## Advanced Features

### Batch Processing
- Process multiple lists simultaneously
- Resume interrupted imports
- Progress tracking and reporting

### TMDB-to-Medusa Configuration Options
```python
config = {
    "dry_run": False,           # Preview mode - don't actually add shows
    "quality_profile": "HD",    # Default quality profile
    "monitor_mode": "all",      # Episode monitoring preference
    "auto_search": True,        # Start searching after adding
    "root_folder": "/tv/",      # Default root folder
    "skip_existing": True,      # Skip shows already in Medusa
    "language_filter": None,    # Filter by original language
    "year_range": [1990, 2025], # Filter by year range
    "batch_size": 10,           # Process shows in batches
    "rate_limit_delay": 0.5,    # Delay between API calls
}
```

### Logging & Reporting
```python
# Example TMDB-to-Medusa log output
INFO  | TMDB-to-Medusa | Processing TMDB list: 'My Watchlist' (142 items)
INFO  | TMDB-to-Medusa | Found show: Breaking Bad (2008) - TVDB ID: 81189
INFO  | TMDB-to-Medusa | Added to Medusa: Breaking Bad
WARN  | TMDB-to-Medusa | No TVDB ID found for: Some Foreign Show
ERROR | TMDB-to-Medusa | Failed to add show: Network timeout
INFO  | TMDB-to-Medusa | Import complete: 45 added, 12 skipped, 3 errors
```

## Usage Examples

### Basic Usage
```bash
python tmdb-to-medusa.py --list-id 12345
```

### Advanced Usage
```bash
python tmdb-to-medusa.py \
  --all-lists \
  --quality-profile "HD" \
  --monitor "pilot" \
  --dry-run
```

### Configuration File
```bash
python tmdb-to-medusa.py --config config.json
```

## Security Considerations

1. **API Key Protection**
   - Never commit API keys to version control
   - Use environment variables or secure config files
   - Consider using key rotation

2. **Network Security**
   - Validate SSL certificates
   - Use HTTPS for all API calls
   - Consider VPN for remote Medusa instances

3. **Error Information**
   - Don't log sensitive information
   - Sanitize error messages
   - Secure log file permissions

## Testing Strategy

### Unit Tests
- Test API response parsing
- Test data mapping functions
- Test error handling scenarios

### Integration Tests
- Test with actual TMDB API (rate limited)
- Test with Medusa test instance
- Test network failure scenarios

### Validation
```python
def validate_show_data(show_data):
    required_fields = ['tvdb_id', 'title', 'root_dir']
    for field in required_fields:
        if not show_data.get(field):
            raise ValueError(f"TMDB-to-Medusa: Missing required field: {field}")
```

## Deployment & Maintenance

### Scheduling
- Use cron for regular imports
- Consider running weekly/monthly
- Monitor for API changes

### Monitoring
- Log successful imports
- Alert on repeated failures
- Track API usage limits

### Updates
- Monitor TMDB API changes
- Monitor Medusa API changes
- Test with new Medusa versions

## Troubleshooting Guide

### Common TMDB-to-Medusa Issues
1. **API Authentication Fails**
   - Verify API keys are correct
   - Check account permissions
   - Ensure URLs are correct

2. **Shows Not Found**
   - Check TMDB to TVDB mapping
   - Try alternative search methods
   - Verify show exists in TVDB

3. **Import Failures**
   - Check Medusa logs
   - Verify root folder permissions
   - Check quality profile settings

### Debug Mode
Enable verbose logging to troubleshoot TMDB-to-Medusa issues:
```bash
python tmdb-to-medusa.py --debug --dry-run
```

## Example TMDB-to-Medusa Implementation Structure

```
TMDB-to-Medusa/
├── src/
│   ├── __init__.py
│   ├── tmdb_client.py      # TMDB API wrapper
│   ├── medusa_client.py    # Medusa API wrapper
│   ├── importer.py         # Main import logic
│   └── utils.py            # Utility functions
├── config/
│   ├── .env.example
│   └── config.json.example
├── tests/
│   ├── test_tmdb_client.py
│   ├── test_medusa_client.py
│   └── test_importer.py
├── logs/
├── requirements.txt
├── README.md
├── CHANGELOG.md
├── LICENSE
└── tmdb-to-medusa.py       # Main entry point
```

## GitHub Repository Setup

### Repository Name
**TMDB-to-Medusa**

### Repository Description
"🐍 Automatically import your TheMovieDB lists into Medusa TV show manager. Bridge TMDB's comprehensive TV data with Medusa's automatic downloading capabilities."

### Tags/Topics
- tmdb
- medusa
- tv-shows
- automation
- python
- import
- watchlist
- arr
- self-hosted

### README.md Structure
```markdown
# TMDB-to-Medusa

Automatically import your TheMovieDB lists into Medusa TV show manager.

## Features
- Import TMDB watchlists and custom lists
- Automatic TMDB to TVDB ID mapping
- Dry-run mode for testing
- Resume interrupted imports
- Comprehensive logging

## Quick Start
[Installation and usage instructions]

## Contributing
[Contribution guidelines]
```

## Community Impact

### Target Audience
- Medusa users wanting TMDB integration
- Self-hosted media server enthusiasts
- Users migrating from Sonarr to Medusa
- TMDB power users with large watchlists

### Potential Growth
- Featured in Medusa documentation
- Referenced in self-hosted communities
- Template for similar projects (TMDB-to-Sonarr, etc.)
- Could become the standard TMDB integration tool

## Conclusion

TMDB-to-Medusa provides a robust solution for importing TMDB lists into Medusa, filling a significant gap in the current ecosystem. The modular design allows for easy maintenance and feature additions, while the comprehensive error handling ensures reliable operation.

This project has the potential to become the go-to solution for TMDB-Medusa integration, benefiting the entire self-hosted media management community.

Remember to test thoroughly with a small subset of shows before running on your entire library, and always backup your Medusa configuration before making bulk changes.

## Resources

- [TMDB API Documentation](https://developers.themoviedb.org/3)
- [Medusa GitHub Repository](https://github.com/pymedusa/Medusa)
- [Medusa API Documentation](https://github.com/pymedusa/Medusa/wiki/API-v2)
- [Python Requests Documentation](https://docs.python-requests.org/)
- [TMDB-to-Medusa GitHub Repository](https://github.com/your-username/TMDB-to-Medusa)

---

**TMDB-to-Medusa** - Bridging the gap between TMDB's data richness and Medusa's automation power.
