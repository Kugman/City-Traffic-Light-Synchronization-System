#!/usr/bin/env python3
"""
Traffic Light Web Server
Connects the Python management system to the HTML visualization via REST API and WebSocket
"""

from flask import Flask, render_template, jsonify, send_from_directory
from flask_socketio import SocketIO, emit
from flask_cors import CORS
import json
import time
import threading
from datetime import datetime
from typing import List, Dict
import os

# Import our traffic management system
import sys
sys.path.append(os.path.dirname(__file__))
from traffic_manager import TrafficLightManager, EmergencyMode, LightState

app = Flask(__name__, static_folder='static', template_folder='.')
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

# Global traffic manager instance
manager = None
simulation_thread = None
simulation_running = False

@app.route('/')
def index():
    """Serve the main HTML page"""
    return send_from_directory('.', 'traffic_visualization_connected.html')

@app.route('/api/status')
def get_status():
    """Get current system status"""
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    metrics = manager.calculate_system_metrics()
    return jsonify({
        'status': 'running' if simulation_running else 'stopped',
        'metrics': metrics,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/lights')
def get_lights():
    """Get all traffic light states"""
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    lights_data = []
    for light in manager.lights[:256]:  # Send first 256 for 16x16 grid
        lights_data.append({
            'id': light.id,
            'x': light.x,
            'y': light.y,
            'state': light.state.value,
            'phase': light.phase,
            'timer': light.timer,
            'green_duration': light.green_duration,
            'traffic_density': light.traffic_density,
            'emergency': light.emergency_mode != EmergencyMode.NORMAL
        })
    
    return jsonify({'lights': lights_data})

@app.route('/api/metrics')
def get_metrics():
    """Get detailed system metrics"""
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    metrics = manager.calculate_system_metrics()
    congested = manager.detect_congestion()
    
    return jsonify({
        'metrics': metrics,
        'congestion': {
            'count': len(congested),
            'intersections': congested[:10]  # Top 10 most congested
        }
    })

@app.route('/api/start', methods=['POST'])
def start_simulation():
    """Start the simulation"""
    global simulation_running, simulation_thread
    
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    if simulation_running:
        return jsonify({'status': 'already running'})
    
    simulation_running = True
    simulation_thread = threading.Thread(target=run_simulation)
    simulation_thread.daemon = True
    simulation_thread.start()
    
    return jsonify({'status': 'started'})

@app.route('/api/stop', methods=['POST'])
def stop_simulation():
    """Stop the simulation"""
    global simulation_running
    simulation_running = False
    return jsonify({'status': 'stopped'})

@app.route('/api/optimize', methods=['POST'])
def optimize_lights():
    """Optimize all traffic light timings"""
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    manager.optimize_timing()
    return jsonify({'status': 'optimized', 'timestamp': datetime.now().isoformat()})

@app.route('/api/greenwave', methods=['POST'])
def create_green_wave():
    """Create a green wave"""
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    # Create green wave on middle row going east
    row = manager.grid_size // 2
    manager.create_green_wave(0, row, 'east')
    
    return jsonify({
        'status': 'green wave created',
        'row': row,
        'direction': 'east'
    })

@app.route('/api/emergency/<vehicle_type>', methods=['POST'])
def activate_emergency(vehicle_type):
    """Activate emergency vehicle route"""
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    # Create emergency route on middle row
    row = manager.grid_size // 2
    route = [(x, row) for x in range(manager.grid_size)]
    
    mode_map = {
        'ambulance': EmergencyMode.AMBULANCE,
        'fire': EmergencyMode.FIRE,
        'police': EmergencyMode.POLICE
    }
    
    if vehicle_type not in mode_map:
        return jsonify({'error': 'Invalid vehicle type'}), 400
    
    manager.handle_emergency_vehicle(route, mode_map[vehicle_type])
    
    return jsonify({
        'status': 'emergency activated',
        'type': vehicle_type,
        'route_length': len(route)
    })

@app.route('/api/emergency/clear', methods=['POST'])
def clear_emergency():
    """Clear emergency mode"""
    if manager is None:
        return jsonify({'error': 'System not initialized'}), 503
    
    manager.clear_emergency_mode()
    return jsonify({'status': 'emergency cleared'})

def run_simulation():
    """Background thread that runs the simulation and broadcasts updates"""
    global simulation_running
    
    print("Simulation thread started")
    
    iteration = 0
    while simulation_running:
        # Update system (10 times per second)
        for _ in range(10):
            if not simulation_running:
                break
            manager.update_system(delta_time=0.1)
        
        # Update traffic patterns every second
        manager.update_traffic_density()
        
        # Optimize timing every 10 seconds
        if iteration % 10 == 0:
            manager.optimize_timing()
        
        # Detect congestion every 5 seconds
        if iteration % 5 == 0:
            congested = manager.detect_congestion()
            if congested and len(congested) > 20:
                # Broadcast congestion alert
                socketio.emit('alert', {
                    'type': 'warning',
                    'title': 'High Congestion',
                    'message': f'{len(congested)} intersections congested'
                })
        
        # Broadcast updates to connected clients
        if iteration % 1 == 0:  # Every second
            lights_data = []
            for light in manager.lights[:256]:  # 16x16 grid
                lights_data.append({
                    'id': light.id,
                    'state': light.state.value,
                    'timer': light.timer,
                    'emergency': light.emergency_mode != EmergencyMode.NORMAL
                })
            
            metrics = manager.calculate_system_metrics()
            
            socketio.emit('update', {
                'lights': lights_data,
                'metrics': metrics,
                'timestamp': datetime.now().isoformat()
            })
        
        iteration += 1
        time.sleep(1)  # Update every second
    
    print("Simulation thread stopped")

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    print('Client connected')
    emit('connected', {'status': 'connected'})
    
    # Send initial state
    if manager is not None:
        lights_data = []
        for light in manager.lights[:256]:
            lights_data.append({
                'id': light.id,
                'x': light.x,
                'y': light.y,
                'state': light.state.value,
                'timer': light.timer,
                'emergency': light.emergency_mode != EmergencyMode.NORMAL
            })
        
        emit('initial_state', {
            'lights': lights_data,
            'metrics': manager.calculate_system_metrics()
        })

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    print('Client disconnected')

def initialize_system():
    """Initialize the traffic management system"""
    global manager
    print("Initializing traffic management system...")
    manager = TrafficLightManager(grid_size=16)  # 16x16 for web visualization
    print(f"✓ System initialized with {len(manager.lights)} traffic lights")

if __name__ == '__main__':
    print("=" * 60)
    print("Traffic Light Management System - Web Server")
    print("=" * 60)
    
    initialize_system()
    
    print("\n🌐 Server starting on http://localhost:5000")
    print("📊 API endpoints:")
    print("   GET  /api/status       - System status")
    print("   GET  /api/lights       - All light states")
    print("   GET  /api/metrics      - System metrics")
    print("   POST /api/start        - Start simulation")
    print("   POST /api/stop         - Stop simulation")
    print("   POST /api/optimize     - Optimize timings")
    print("   POST /api/greenwave    - Create green wave")
    print("   POST /api/emergency/:type - Emergency route")
    print("   POST /api/emergency/clear - Clear emergency")
    print("\n🔌 WebSocket: Real-time updates on ws://localhost:5000")
    print("\nPress Ctrl+C to stop the server\n")
    
    socketio.run(app, host='0.0.0.0', port=5000, debug=True, allow_unsafe_werkzeug=True)
