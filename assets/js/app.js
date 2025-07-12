// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
// Import Mapbox for location search
import mapboxgl from 'mapbox-gl'
import MapboxGeocoder from '@mapbox/mapbox-gl-geocoder'

let Hooks = {}

Hooks.ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

Hooks.LocationSearch = {
  mounted() {
    // Get Mapbox token from meta tag
    const mapboxToken = document.querySelector("meta[name='mapbox-token']")?.getAttribute("content")
    if (!mapboxToken) {
      console.error("Mapbox token not found")
      return
    }

    mapboxgl.accessToken = mapboxToken
    
    // Create geocoder instance
    const geocoder = new MapboxGeocoder({
      accessToken: mapboxToken,
      types: 'address',
      countries: 'us', // Restrict to US only
      placeholder: 'Search for an address...',
      mapboxgl: mapboxgl
    })

    // Replace the input with the geocoder
    const input = this.el
    const locationType = input.dataset.locationType // 'pickup' or 'destination'
    
    // Create a wrapper div and append the geocoder
    const wrapper = document.createElement('div')
    wrapper.className = 'mapbox-geocoder-wrapper'
    input.parentNode.insertBefore(wrapper, input)
    wrapper.appendChild(geocoder.onAdd())
    
    // Hide the original input
    input.style.display = 'none'
    
    // Handle geocoder result
    geocoder.on('result', (e) => {
      const result = e.result
      const address = result.place_name
      const coordinates = result.geometry.coordinates // [lng, lat]
      
      // Update the hidden input with the address
      input.value = address
      
      // Send coordinates to LiveView
      this.pushEvent("update_coordinates", {
        type: locationType,
        address: address,
        lat: coordinates[1],
        lng: coordinates[0]
      })
      
      // Trigger change event on the input
      const event = new Event('input', { bubbles: true })
      input.dispatchEvent(event)
    })
    
    // Handle geocoder clear
    geocoder.on('clear', () => {
      input.value = ''
      this.pushEvent("clear_coordinates", {
        type: locationType
      })
      
      const event = new Event('input', { bubbles: true })
      input.dispatchEvent(event)
    })
  }
}

Hooks.PrivacyRadiusMap = {
  mounted() {
    const mapboxToken = document.querySelector("meta[name='mapbox-token']")?.getAttribute("content")
    if (!mapboxToken) {
      console.error("Mapbox token not found")
      return
    }

    mapboxgl.accessToken = mapboxToken
    
    const locationType = this.el.dataset.locationType
    const lat = parseFloat(this.el.dataset[`${locationType}Lat`])
    const lng = parseFloat(this.el.dataset[`${locationType}Lng`])
    
    if (!lat || !lng) {
      this.el.innerHTML = '<div class="flex items-center justify-center h-full text-base-content/50">Location data not available</div>'
      return
    }

    // Create map centered on location
    const map = new mapboxgl.Map({
      container: this.el,
      style: 'mapbox://styles/mapbox/light-v11',
      center: [lng, lat],
      zoom: 12
    })

    map.on('load', () => {
      // Calculate 3-mile radius circle
      const radiusMeters = 3 * 1609.344 // 3 miles in meters
      const options = { steps: 64, units: 'meters' }
      
      // Create circle using turf.js-like calculation
      const center = [lng, lat]
      const circle = this.createCircle(center, radiusMeters, options)

      // Add circle as a source
      map.addSource('privacy-radius', {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: circle
        }
      })

      // Add circle fill
      map.addLayer({
        id: 'privacy-radius-fill',
        type: 'fill',
        source: 'privacy-radius',
        paint: {
          'fill-color': '#3b82f6',
          'fill-opacity': 0.2
        }
      })

      // Add circle outline
      map.addLayer({
        id: 'privacy-radius-outline',
        type: 'line',
        source: 'privacy-radius',
        paint: {
          'line-color': '#3b82f6',
          'line-width': 2
        }
      })
    })

    this.map = map
  },

  destroyed() {
    if (this.map) {
      this.map.remove()
    }
  },

  createCircle(center, radiusInMeters, options = {}) {
    const steps = options.steps || 64
    const coordinates = []
    
    for (let i = 0; i < steps; i++) {
      const angle = (i * 360) / steps
      const point = this.destination(center, radiusInMeters / 1000, angle)
      coordinates.push(point)
    }
    
    coordinates.push(coordinates[0]) // Close the circle
    
    return {
      type: 'Polygon',
      coordinates: [coordinates]
    }
  },

  destination(origin, distance, bearing) {
    const radius = 6371 // Earth's radius in km
    const lat1 = origin[1] * Math.PI / 180
    const lng1 = origin[0] * Math.PI / 180
    const bearingRad = bearing * Math.PI / 180
    
    const lat2 = Math.asin(
      Math.sin(lat1) * Math.cos(distance / radius) +
      Math.cos(lat1) * Math.sin(distance / radius) * Math.cos(bearingRad)
    )
    
    const lng2 = lng1 + Math.atan2(
      Math.sin(bearingRad) * Math.sin(distance / radius) * Math.cos(lat1),
      Math.cos(distance / radius) - Math.sin(lat1) * Math.sin(lat2)
    )
    
    return [lng2 * 180 / Math.PI, lat2 * 180 / Math.PI]
  }
}

Hooks.ExactLocationMap = {
  mounted() {
    const mapboxToken = document.querySelector("meta[name='mapbox-token']")?.getAttribute("content")
    if (!mapboxToken) {
      console.error("Mapbox token not found")
      return
    }

    mapboxgl.accessToken = mapboxToken
    
    const pickupLat = parseFloat(this.el.dataset.pickupLat)
    const pickupLng = parseFloat(this.el.dataset.pickupLng)
    const destLat = parseFloat(this.el.dataset.destinationLat)
    const destLng = parseFloat(this.el.dataset.destinationLng)
    
    if (!pickupLat || !pickupLng || !destLat || !destLng) {
      this.el.innerHTML = '<div class="flex items-center justify-center h-full text-base-content/50">Location data not available</div>'
      return
    }

    // Calculate bounds to fit both markers
    const bounds = new mapboxgl.LngLatBounds()
    bounds.extend([pickupLng, pickupLat])
    bounds.extend([destLng, destLat])

    // Create map
    const map = new mapboxgl.Map({
      container: this.el,
      style: 'mapbox://styles/mapbox/streets-v12',
      bounds: bounds,
      fitBoundsOptions: { padding: 50 }
    })

    // Add pickup marker
    new mapboxgl.Marker({ color: '#10b981' }) // success color
      .setLngLat([pickupLng, pickupLat])
      .setPopup(new mapboxgl.Popup().setHTML(`
        <div class="p-2">
          <strong>📍 Pickup</strong><br>
          ${this.el.dataset.pickupName}<br>
          <small>${this.el.dataset.pickupAddress}</small>
        </div>
      `))
      .addTo(map)

    // Add destination marker
    new mapboxgl.Marker({ color: '#ef4444' }) // error color
      .setLngLat([destLng, destLat])
      .setPopup(new mapboxgl.Popup().setHTML(`
        <div class="p-2">
          <strong>🎯 Destination</strong><br>
          ${this.el.dataset.destinationName}<br>
          <small>${this.el.dataset.destinationAddress}</small>
        </div>
      `))
      .addTo(map)

    this.map = map
  },

  destroyed() {
    if (this.map) {
      this.map.remove()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

