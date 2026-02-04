# City Traffic Light Synchronization System

A GPU-accelerated traffic light management system using HIP (Heterogeneous-compute Interface for Portability) that optimizes traffic flow through intelligent synchronization and real-time adaptation.

## 🚦 Project Overview

This system demonstrates the advantages of HIP development by creating a portable, high-performance traffic light management solution that can run on both AMD and NVIDIA GPUs. The system manages thousands of traffic lights simultaneously, optimizing timing based on real-time traffic data and creating synchronized green waves for better traffic flow.

## 🎯 Features

### GPU-Accelerated Core (HIP)
- **Parallel State Updates**: Updates all traffic lights simultaneously on GPU
- **Traffic Flow Optimization**: Calculates optimal green light durations based on traffic density
- **Green Wave Synchronization**: Creates coordinated green waves along corridors
- **Congestion Detection**: Real-time identification and response to traffic congestion
- **Emergency Vehicle Priority**: Clears paths for emergency vehicles

### Management System (Python)
- **Real-time Traffic Simulation**: Models changing traffic patterns
- **Emergency Route Management**: Handles ambulance, fire truck, and police vehicle routes
- **Performance Metrics**: Calculates system-wide traffic statistics
- **State Export**: JSON export of complete system state
- **Comprehensive Reporting**: Generates detailed status reports

### Visualization Interface (HTML/JavaScript)
- **Live Grid Display**: Real-time visualization of traffic light states
- **Interactive Controls**: Manual optimization and emergency activation
- **Metrics Dashboard**: Live system performance monitoring
- **Alert System**: Real-time notifications for congestion and events

## 🏗️ Architecture

```
┌───────────────────────────────────────────────────────────┐
│         Web Browser (traffic_visualization_connected.html)│
│         - Real-time visualization                         │
│         - Interactive controls                            │
└────────────────────┬──────────────────────────────────────┘
                     │ WebSocket + REST API
                     │ (Socket.IO)
┌────────────────────▼─────────────────────────────────────┐
│              Flask Web Server (traffic_server.py)        │
│              - REST API endpoints                        │
│              - WebSocket broadcasting                    │
│              - Real-time updates                         │
└────────────────────┬─────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────┐
│         Traffic Management System (traffic_manager.py)   │
│         - Simulation engine                              │
│         - Traffic optimization                           │
│         - Emergency handling                             │
└──────────────────────────────────────────────────────────┘
```

## 🚀 Why HIP?

This project was developed in HIP instead of CUDA for **hardware portability**:

1. **Cross-Vendor Support**: The same code runs on both AMD and NVIDIA GPUs
2. **Performance Parity**: On NVIDIA hardware, HIP code achieves near-identical performance to CUDA
3. **Future-Proofing**: Not locked into a single vendor's ecosystem
4. **Strategic Flexibility**: Can deploy on whatever hardware is available or cost-effective

## 📋 Requirements

### For HIP (GPU) Version
- HIP-capable GPU (AMD Radeon or NVIDIA with HIP support)
- ROCm 5.0+ (AMD) or CUDA 11.0+ with HIP (NVIDIA)
- CMake 3.16+
- C++14 compatible compiler

### For Python Management System
- Python 3.7+
- No external dependencies (uses only standard library)

### For Visualization
- Modern web browser with JavaScript enabled

## 🔧 Installation & Building

### 1. Build the HIP Application

```bash
# Create build directory
mkdir build && cd build

# Configure with CMake
cmake ..

# Build
make

# Run
./traffic_sync
```

### 2. Run the Python Management System

```bash
# Make executable
chmod +x traffic_manager.py

# Run simulation
python3 traffic_manager.py
```

### 3. Open the Visualization

```bash
# Open in your browser
firefox traffic_visualization.html
# or
google-chrome traffic_visualization.html
```

## 💻 Usage Examples

### Basic HIP Simulation
```bash
./traffic_sync
```

Output:
```
=== City Traffic Light Synchronization System (HIP) ===

Managing 1024 traffic lights in 32x32 grid
Block size: 256, Grid size: 4

Running simulation for 300 seconds...
[t=0s] Avg flow: 1.23, Max congestion: 0.87
[t=60s] Avg flow: 1.18, Max congestion: 0.82
...
```

### Python Management with Emergency Route
```python
from traffic_manager import TrafficLightManager, EmergencyMode

manager = TrafficLightManager(grid_size=32)

# Create emergency route for ambulance
emergency_route = [(x, 16) for x in range(32)]
manager.handle_emergency_vehicle(emergency_route, EmergencyMode.AMBULANCE)

# Generate report
print(manager.generate_report())
```

### Green Wave Creation
```python
# Create coordinated green wave going east on street 16
manager.create_green_wave(start_x=0, start_y=16, direction='east', 
                         avg_speed=15.0, block_distance=200.0)
```

## 🎮 Interactive Controls

The web visualization provides:

- **Optimize All Lights**: Recalculates timing for all intersections
- **Create Green Wave**: Generates a progressive green wave
- **Emergency Routes**: Simulates ambulance, fire truck, or police routes
- **Pause/Resume**: Control simulation flow
- **Click Lights**: View detailed intersection information

## 📊 Performance Characteristics

### GPU Kernels
- **updateTrafficLights**: O(N) - one thread per light
- **optimizeGreenDurations**: O(N) - considers neighbors
- **synchronizeGreenWave**: O(N×K) - K connected lights
- **detectCongestion**: O(N) - parallel congestion check
- **calculateFlowMetrics**: O(N) - parallel reduction

### Scalability
- Tested with 32×32 grid (1,024 lights)
- Can scale to 100×100 grid (10,000 lights) or more
- Real-time performance at 10Hz update rate

## 🔬 Algorithms

### Adaptive Green Duration
```
green_duration = min_time + (max_time - min_time) × density
where density = 0.7 × local_density + 0.3 × neighbor_density
```

### Green Wave Synchronization
```
offset = distance / avg_vehicle_speed
timer_adjustment = offset % cycle_time
```

### Congestion Response
```
if traffic_density > threshold:
    extend_green_time(+5 seconds)
```

## 📁 Project Structure

```
.
├── traffic_sync.hip              # Main HIP kernel code
├── traffic_manager.py            # Python management system
├── traffic_visualization.html    # Web interface
└── README.md                     # This file
```

## 🔍 Code Highlights

### HIP Kernel Example
```cpp
__global__ void updateTrafficLights(TrafficLight* lights, int num_lights, float delta_time) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_lights) return;
    
    TrafficLight* light = &lights[idx];
    light->timer -= delta_time;
    
    if (light->timer <= 0) {
        // State transition logic
        if (light->state == GREEN) {
            light->state = YELLOW;
        } // ... etc
    }
}
```

### Emergency Route Clearing
```python
def handle_emergency_vehicle(self, route, vehicle_type):
    # Set all lights in route to GREEN
    for light_id in route_light_ids:
        light.state = LightState.GREEN
        light.timer = 60.0
    
    # Set perpendicular lights to RED
    for neighbor in perpendicular_lights:
        neighbor.state = LightState.RED
```

## 🎯 Future Enhancements

- [ ] Machine learning for traffic prediction
- [ ] Weather-adaptive timing
- [ ] Pedestrian crossing optimization
- [ ] Real sensor data integration
- [ ] Mobile app for emergency vehicles
- [ ] 3D visualization with WebGL

## 🤝 Contributing

This is a demonstration project showing HIP development advantages. Feel free to:
- Extend the simulation with more realistic traffic models
- Add additional optimization algorithms
- Improve the visualization
- Port to other GPU programming models for comparison

## 📚 References

- HIP Programming Guide: https://rocm.docs.amd.com/projects/HIP/
- Traffic Flow Theory: Highway Capacity Manual
- Green Wave Timing: TRANSYT optimization methods

## 💡 Key Takeaways

1. **HIP enables portable GPU code** - Write once, run on AMD and NVIDIA
2. **GPU acceleration is ideal for traffic systems** - Thousands of lights updated in parallel
3. **Real-time optimization is feasible** - 10+ Hz update rates with complex calculations
4. **Visualization enhances understanding** - Interactive interface makes complex systems accessible

---

**Built with HIP**
