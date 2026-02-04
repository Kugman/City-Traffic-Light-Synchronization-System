#!/usr/bin/env python3
"""
Traffic Light Management System
Provides a web-based interface for monitoring and controlling city traffic lights
"""

import json
import time
import random
import math
from datetime import datetime
from typing import List, Dict, Tuple
from dataclasses import dataclass, asdict
from enum import Enum

class LightState(Enum):
    RED = 0
    YELLOW = 1
    GREEN = 2

class EmergencyMode(Enum):
    NORMAL = 0
    AMBULANCE = 1
    FIRE = 2
    POLICE = 3

@dataclass
class TrafficLight:
    id: int
    x: int
    y: int
    state: LightState
    phase: int
    timer: float
    green_duration: float
    yellow_duration: float
    traffic_density: List[float]
    connected_lights: List[int]
    emergency_mode: EmergencyMode = EmergencyMode.NORMAL

@dataclass
class IntersectionMetrics:
    intersection_id: int
    avg_wait_time: float
    throughput: float
    congestion_level: float
    incidents: int
    timestamp: str

class TrafficLightManager:
    def __init__(self, grid_size: int = 32):
        self.grid_size = grid_size
        self.lights: List[TrafficLight] = []
        self.metrics: Dict[int, IntersectionMetrics] = {}
        self.emergency_routes: List[List[int]] = []
        self.initialize_system()
    
    def initialize_system(self):
        """Initialize all traffic lights in the city grid"""
        print(f"Initializing {self.grid_size}x{self.grid_size} traffic grid...")
        
        for i in range(self.grid_size * self.grid_size):
            x = i % self.grid_size
            y = i // self.grid_size
            
            # Stagger initial states for better flow
            initial_state = LightState.GREEN if i % 4 == 0 else LightState.RED
            phase = i % 4
            
            # Initialize traffic density (higher during rush hours)
            hour = datetime.now().hour
            rush_hour_multiplier = 1.5 if (7 <= hour <= 9 or 16 <= hour <= 18) else 1.0
            density = [random.uniform(0.2, 0.8) * rush_hour_multiplier for _ in range(4)]
            
            # Connect to neighboring lights
            connected = [
                i - self.grid_size if y > 0 else -1,  # North
                i + 1 if x < self.grid_size - 1 else -1,  # East
                i + self.grid_size if y < self.grid_size - 1 else -1,  # South
                i - 1 if x > 0 else -1  # West
            ]
            
            light = TrafficLight(
                id=i,
                x=x,
                y=y,
                state=initial_state,
                phase=phase,
                timer=30.0,
                green_duration=30.0,
                yellow_duration=3.0,
                traffic_density=density,
                connected_lights=connected
            )
            
            self.lights.append(light)
            
            # Initialize metrics
            self.metrics[i] = IntersectionMetrics(
                intersection_id=i,
                avg_wait_time=0.0,
                throughput=0.0,
                congestion_level=0.0,
                incidents=0,
                timestamp=datetime.now().isoformat()
            )
        
        print(f"✓ Initialized {len(self.lights)} traffic lights")
    
    def update_system(self, delta_time: float = 0.1):
        """Update all traffic light states"""
        for light in self.lights:
            light.timer -= delta_time
            
            if light.timer <= 0:
                if light.state == LightState.GREEN:
                    light.state = LightState.YELLOW
                    light.timer = light.yellow_duration
                elif light.state == LightState.YELLOW:
                    light.state = LightState.RED
                    light.phase = (light.phase + 1) % 4
                    light.timer = 2.0  # Red clearance time
                elif light.state == LightState.RED:
                    light.state = LightState.GREEN
                    light.timer = light.green_duration
    
    def optimize_timing(self):
        """Optimize green light durations based on traffic density"""
        for light in self.lights:
            if light.emergency_mode != EmergencyMode.NORMAL:
                continue
            
            # Calculate average density for current phase
            current_density = light.traffic_density[light.phase]
            
            # Consider neighbor densities
            neighbor_density = 0.0
            neighbor_count = 0
            
            for neighbor_id in light.connected_lights:
                if 0 <= neighbor_id < len(self.lights):
                    neighbor_density += sum(self.lights[neighbor_id].traffic_density) / 4
                    neighbor_count += 1
            
            if neighbor_count > 0:
                neighbor_density /= neighbor_count
            
            # Adaptive timing: 20-60 seconds based on density
            combined_density = current_density * 0.7 + neighbor_density * 0.3
            light.green_duration = 20.0 + 40.0 * combined_density
    
    def create_green_wave(self, start_x: int, start_y: int, direction: str, 
                          avg_speed: float = 15.0, block_distance: float = 200.0):
        """Create a green wave along a corridor"""
        if direction not in ['north', 'south', 'east', 'west']:
            return
        
        print(f"Creating green wave from ({start_x},{start_y}) going {direction}")
        
        lights_in_wave = []
        x, y = start_x, start_y
        
        # Collect lights along the corridor
        while 0 <= x < self.grid_size and 0 <= y < self.grid_size:
            light_id = y * self.grid_size + x
            lights_in_wave.append(light_id)
            
            if direction == 'north':
                y -= 1
            elif direction == 'south':
                y += 1
            elif direction == 'east':
                x += 1
            elif direction == 'west':
                x -= 1
        
        # Synchronize lights for progressive flow
        travel_time = block_distance / avg_speed
        
        for i, light_id in enumerate(lights_in_wave):
            light = self.lights[light_id]
            offset = i * travel_time
            
            # Adjust phase timing
            cycle_time = light.green_duration + light.yellow_duration + 2.0
            light.timer = cycle_time - (offset % cycle_time)
        
        print(f"✓ Synchronized {len(lights_in_wave)} lights for green wave")
    
    def handle_emergency_vehicle(self, route: List[Tuple[int, int]], 
                                 vehicle_type: EmergencyMode):
        """Clear path for emergency vehicle"""
        print(f"🚨 Emergency {vehicle_type.name} vehicle route activated")
        
        route_light_ids = []
        for x, y in route:
            light_id = y * self.grid_size + x
            if 0 <= light_id < len(self.lights):
                route_light_ids.append(light_id)
        
        # Set all lights in route to GREEN
        for light_id in route_light_ids:
            light = self.lights[light_id]
            light.emergency_mode = vehicle_type
            light.state = LightState.GREEN
            light.timer = 60.0  # Hold green for 1 minute
        
        # Set perpendicular lights to RED
        for light_id in route_light_ids:
            light = self.lights[light_id]
            for neighbor_id in light.connected_lights:
                if 0 <= neighbor_id < len(self.lights):
                    neighbor = self.lights[neighbor_id]
                    if neighbor_id not in route_light_ids:
                        neighbor.state = LightState.RED
                        neighbor.timer = 60.0
        
        self.emergency_routes.append(route_light_ids)
        print(f"✓ Emergency route cleared: {len(route_light_ids)} intersections")
    
    def clear_emergency_mode(self):
        """Return all lights to normal operation"""
        for light in self.lights:
            if light.emergency_mode != EmergencyMode.NORMAL:
                light.emergency_mode = EmergencyMode.NORMAL
        
        self.emergency_routes.clear()
        print("✓ Emergency mode cleared, returning to normal operation")
    
    def detect_congestion(self, threshold: float = 0.7):
        """Detect and report congested intersections"""
        congested = []
        
        for light in self.lights:
            avg_density = sum(light.traffic_density) / len(light.traffic_density)
            
            if avg_density > threshold:
                congested.append({
                    'id': light.id,
                    'location': (light.x, light.y),
                    'density': avg_density,
                    'current_green': light.green_duration
                })
                
                # Extend green time for congested intersections
                light.green_duration = min(60.0, light.green_duration * 1.3)
        
        return congested
    
    def update_traffic_density(self):
        """Simulate changing traffic patterns"""
        for light in self.lights:
            for i in range(4):
                # Random walk with trend
                change = random.gauss(0, 0.05)
                light.traffic_density[i] = max(0.0, min(1.0, 
                    light.traffic_density[i] + change))
    
    def calculate_system_metrics(self) -> Dict:
        """Calculate overall system performance metrics"""
        total_density = 0.0
        max_density = 0.0
        avg_green_duration = 0.0
        
        for light in self.lights:
            density = sum(light.traffic_density) / len(light.traffic_density)
            total_density += density
            max_density = max(max_density, density)
            avg_green_duration += light.green_duration
        
        return {
            'total_intersections': len(self.lights),
            'avg_traffic_density': total_density / len(self.lights),
            'max_congestion': max_density,
            'avg_green_duration': avg_green_duration / len(self.lights),
            'emergency_routes_active': len(self.emergency_routes),
            'timestamp': datetime.now().isoformat()
        }
    
    def export_state(self, filename: str = "traffic_state.json"):
        """Export current system state to JSON"""
        state = {
            'grid_size': self.grid_size,
            'timestamp': datetime.now().isoformat(),
            'lights': [
                {
                    'id': light.id,
                    'position': (light.x, light.y),
                    'state': light.state.name,
                    'phase': light.phase,
                    'timer': light.timer,
                    'green_duration': light.green_duration,
                    'traffic_density': light.traffic_density,
                    'emergency_mode': light.emergency_mode.name
                }
                for light in self.lights
            ],
            'metrics': self.calculate_system_metrics()
        }
        
        with open(filename, 'w') as f:
            json.dump(state, f, indent=2)
        
        print(f"✓ System state exported to {filename}")
    
    def generate_report(self) -> str:
        """Generate a text report of system status"""
        metrics = self.calculate_system_metrics()
        congested = self.detect_congestion()
        
        report = f"""
╔══════════════════════════════════════════════════════════════╗
║        CITY TRAFFIC LIGHT MANAGEMENT SYSTEM REPORT           ║
╠══════════════════════════════════════════════════════════════╣
║ Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}    ║
║ Grid Size: {self.grid_size}x{self.grid_size} ({metrics['total_intersections']} intersections)                    ║
╠══════════════════════════════════════════════════════════════╣
║ TRAFFIC METRICS                                              ║
║ Average Traffic Density: {metrics['avg_traffic_density']:.2%}║
║ Maximum Congestion: {metrics['max_congestion']:.2%}          ║
║ Average Green Duration: {metrics['avg_green_duration']:.1f}s ║
║ Emergency Routes Active: {metrics['emergency_routes_active']}║
╠══════════════════════════════════════════════════════════════╣
║ CONGESTION ALERTS ({len(congested)} intersections)           ║
"""
        
        for i, intersection in enumerate(congested[:5]):
            report += f"║ {i+1}. Intersection {intersection['id']:4d} at ({intersection['location'][0]:2d},{intersection['location'][1]:2d}) - Density: {intersection['density']:.1%} ║\n"
        
        if len(congested) > 5:
            report += f"║ ... and {len(congested) - 5} more congested intersections                 ║\n"
        
        report += "╚══════════════════════════════════════════════════════════════╝\n"
        
        return report


def main():
    """Main function demonstrating the traffic management system"""
    print("🚦 City Traffic Light Management System 🚦\n")
    
    # Initialize system
    manager = TrafficLightManager(grid_size=32)
    
    # Simulate system operation
    print("\n--- Starting 60-second simulation ---\n")
    
    for second in range(60):
        # Update system every 0.1 seconds
        for _ in range(10):
            manager.update_system(delta_time=0.1)
        
        # Update traffic patterns every second
        manager.update_traffic_density()
        
        # Optimize timing every 10 seconds
        if second % 10 == 0:
            manager.optimize_timing()
        
        # Create green wave on main street every 30 seconds
        if second % 30 == 0:
            manager.create_green_wave(0, 16, 'east')
        
        # Check for congestion every 15 seconds
        if second % 15 == 0:
            congested = manager.detect_congestion()
            if congested:
                print(f"[{second}s] ⚠️  {len(congested)} congested intersections detected")
        
        # Simulate emergency vehicle at 20 seconds
        if second == 20:
            emergency_route = [(x, 16) for x in range(32)]
            manager.handle_emergency_vehicle(emergency_route, EmergencyMode.AMBULANCE)
        
        # Clear emergency at 35 seconds
        if second == 35:
            manager.clear_emergency_mode()
        
        # Progress indicator
        if second % 5 == 0:
            metrics = manager.calculate_system_metrics()
            print(f"[{second}s] Traffic density: {metrics['avg_traffic_density']:.1%}, "
                  f"Avg green: {metrics['avg_green_duration']:.1f}s")
    
    print("\n" + manager.generate_report())
    
    # Export final state
    manager.export_state("/home/claude/traffic_state.json")
    
    print("\n✓ Simulation complete!")


if __name__ == "__main__":
    main()
