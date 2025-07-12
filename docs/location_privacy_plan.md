# Location Privacy System Implementation Plan

## Overview
This document outlines the implementation plan for the location privacy system in CarlosAssist. The system allows riders to enter locations with friendly names while keeping actual addresses private until a volunteer match is made.

**Core Specifications:**
- Service Area: United States
- Privacy Radius: 3 mile radius for volunteer preview
- No saved locations in initial release
- No location verification required
- Using Mapbox for mapping services

## Phase 1: Technical Setup & Infrastructure

### 1.1 Database Migration
```elixir
# Key fields to add to rides table:
- pickup_name (string)          # Public name like "Home" 
- pickup_address (string)       # Private full address
- pickup_lat (decimal)         # For mapping
- pickup_long (decimal)        # For mapping
- destination_name (string)     # Public name like "Doctor"
- destination_address (string)  # Private full address
- destination_lat (decimal)    # For mapping
- destination_long (decimal)   # For mapping
```

**Important Notes:**
- Keep existing fields for backward compatibility
- Add indexes for coordinate pairs
- Consider encryption for address fields

### 1.2 Mapbox Integration
1. **Account Setup**
   - Create Mapbox account
   - Get API tokens
   - Set up usage monitoring

2. **Environment Configuration**
   ```
   # Required env variables:
   MAPBOX_PUBLIC_KEY=pk.xxx    # For client-side
   MAPBOX_PRIVATE_KEY=sk.xxx   # For server-side
   ```
   **Note:** Never commit API keys to version control

### 1.3 JavaScript Package Setup
```javascript
// Required packages:
- @mapbox/mapbox-gl-js
- @mapbox/mapbox-gl-geocoder
```

## Phase 2: Ride Creation Form Enhancement

### 2.1 Form Structure
```heex
<div class="location-section">
  <!-- Pickup Section -->
  <div class="public-info">
    <label>Nickname for pickup location</label>
    <input>
    <helper-text>This is what volunteers will see</helper-text>
  </div>
  
  <div class="private-info">
    <label>Actual address (kept private)</label>
    <address-search>
    <map-preview>
  </div>

  <!-- Similar structure for destination -->
</div>
```

**Key Points:**
- Clear visual separation between public/private
- Helper text for each section
- Privacy indicators

### 2.2 Address Search Component
```javascript
// Features needed:
- Address autocomplete
- US-only results
- Coordinate extraction
- Map preview update
```

## Phase 3: Privacy Implementation

### 3.1 Location Privacy System
```elixir
# Core privacy rules:
1. Before match:
   - Show only location nickname
   - Display 3-mile radius circle
   - Show general area name

2. After match:
   - Reveal exact address
   - Show precise location
```

### 3.2 Map Display Logic
```javascript
// Two display modes:
1. Privacy Mode (pre-match):
   - Generate 3-mile radius circle
   - Center on actual location
   - Hide exact marker

2. Exact Mode (post-match):
   - Show precise marker
   - Enable navigation
```

## Phase 4: Volunteer Interface

### 4.1 Ride List View
```heex
<div class="ride-card">
  <!-- Public Info -->
  <div class="location-summary">
    From: {pickup_name}
    To: {destination_name}
    Area: {general_area}
  </div>

  <!-- Map Preview -->
  <div class="map-preview">
    <!-- 3-mile radius circle -->
  </div>
</div>
```

### 4.2 Matched Ride View
```heex
<div class="matched-ride-details">
  <!-- Full Info -->
  <div class="location-details">
    Exact addresses
    Navigation options
    Precise map
  </div>
</div>
```

## Implementation Schedule

### Week 1: Foundation
- [ ] Database migration
- [ ] Mapbox setup
- [ ] Basic form updates

### Week 2: Location Input
- [ ] Address search implementation
- [ ] Map preview
- [ ] Coordinate handling

### Week 3: Privacy Features
- [ ] Privacy radius implementation
- [ ] Access control system
- [ ] Data masking

### Week 4: Volunteer Interface
- [ ] Ride list view
- [ ] Privacy map display
- [ ] Matched ride view

## Testing Checklist

### Privacy Tests
- [ ] Verify private data is hidden pre-match
- [ ] Confirm data access after match
- [ ] Test radius display accuracy
- [ ] Validate coordinate privacy

### User Experience Tests
- [ ] Test form flow
- [ ] Verify address search usability
- [ ] Check map interactions
- [ ] Validate mobile responsiveness

### Technical Tests
- [ ] API error handling
- [ ] Coordinate accuracy
- [ ] Map rendering performance
- [ ] Data storage security

## Key Points to Remember

### 1. Privacy First
- Always validate privacy server-side
- Log sensitive data access
- Clear privacy indicators

### 2. User Experience
- Clear instructions
- Helpful error messages
- Simple, intuitive flow

### 3. Technical Considerations
- API usage monitoring
- Error handling
- Mobile responsiveness

### 4. Future Expansion
- Design for adding saved locations later
- Consider multi-stop capability
- Plan for area restrictions

## Notes
- Implementation order can be adjusted based on team availability and priorities
- All privacy features must be tested thoroughly before deployment
- Consider user testing with elderly users for usability feedback
- Monitor Mapbox API usage and costs during development 