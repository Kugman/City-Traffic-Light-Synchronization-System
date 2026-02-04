#include <hip/hip_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define MAX_LIGHTS 1000
#define GRID_SIZE 32  // 32x32 city grid
#define PHASES 4      // North, East, South, West

// Traffic light states
typedef enum {
    RED = 0,
    YELLOW = 1,
    GREEN = 2
} LightState;

// Traffic light structure
typedef struct {
    int id;
    int x, y;           // Grid position
    LightState state;
    int phase;          // Current phase (0-3)
    float timer;        // Time until next state change
    float green_duration;
    float yellow_duration;
    float traffic_density[PHASES];  // Traffic density in each direction
    int connected_lights[4];        // IDs of connected lights
} TrafficLight;

// Traffic flow data
typedef struct {
    float flow_rate[GRID_SIZE][GRID_SIZE][PHASES];
    float congestion[GRID_SIZE][GRID_SIZE];
} TrafficData;

// GPU kernel to update traffic light states based on synchronized timing
__global__ void updateTrafficLights(TrafficLight* lights, int num_lights, float delta_time) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (idx >= num_lights) return;
    
    TrafficLight* light = &lights[idx];
    light->timer -= delta_time;
    
    if (light->timer <= 0) {
        // Transition states
        if (light->state == GREEN) {
            light->state = YELLOW;
            light->timer = light->yellow_duration;
        } else if (light->state == YELLOW) {
            light->state = RED;
            // Move to next phase
            light->phase = (light->phase + 1) % PHASES;
            light->timer = 2.0f; // Red clearance time
        } else if (light->state == RED) {
            light->state = GREEN;
            light->timer = light->green_duration;
        }
    }
}

// GPU kernel to calculate optimal green light durations based on traffic density
__global__ void optimizeGreenDurations(TrafficLight* lights, TrafficData* traffic, 
                                       int num_lights, float min_green, float max_green) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (idx >= num_lights) return;
    
    TrafficLight* light = &lights[idx];
    int x = light->x;
    int y = light->y;
    
    // Calculate weighted traffic density for current phase
    float current_density = traffic->flow_rate[x][y][light->phase];
    
    // Consider neighboring intersections
    float neighbor_density = 0.0f;
    int neighbor_count = 0;
    
    for (int i = 0; i < 4; i++) {
        int neighbor_id = light->connected_lights[i];
        if (neighbor_id >= 0 && neighbor_id < num_lights) {
            neighbor_density += lights[neighbor_id].traffic_density[i];
            neighbor_count++;
        }
    }
    
    if (neighbor_count > 0) {
        neighbor_density /= neighbor_count;
    }
    
    // Adaptive green duration based on traffic
    float combined_density = current_density * 0.7f + neighbor_density * 0.3f;
    light->green_duration = min_green + (max_green - min_green) * combined_density;
}

// GPU kernel to synchronize traffic lights for green wave progression
__global__ void synchronizeGreenWave(TrafficLight* lights, int num_lights, 
                                     float avg_speed, float block_distance) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (idx >= num_lights) return;
    
    TrafficLight* light = &lights[idx];
    
    // Calculate optimal offset based on distance and average vehicle speed
    float travel_time = block_distance / avg_speed;
    
    // Synchronize with upstream lights
    for (int i = 0; i < 4; i++) {
        int upstream_id = light->connected_lights[i];
        if (upstream_id >= 0 && upstream_id < num_lights) {
            TrafficLight* upstream = &lights[upstream_id];
            
            // Calculate phase offset for green wave
            int dx = light->x - upstream->x;
            int dy = light->y - upstream->y;
            float distance = sqrtf((float)(dx*dx + dy*dy)) * block_distance;
            float offset = fmodf(distance / avg_speed, 
                               light->green_duration + light->yellow_duration + 2.0f);
            
            // Adjust timer for coordination (simplified)
            if (upstream->state == GREEN && light->state == RED) {
                light->timer = fminf(light->timer, offset);
            }
        }
    }
}

// GPU kernel to detect and resolve traffic congestion
__global__ void detectCongestion(TrafficLight* lights, TrafficData* traffic, 
                                 int num_lights, float congestion_threshold) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (idx >= num_lights) return;
    
    TrafficLight* light = &lights[idx];
    int x = light->x;
    int y = light->y;
    
    float total_flow = 0.0f;
    for (int i = 0; i < PHASES; i++) {
        total_flow += traffic->flow_rate[x][y][i];
    }
    
    traffic->congestion[x][y] = total_flow;
    
    // Emergency mode: extend green if severe congestion
    if (total_flow > congestion_threshold && light->state == GREEN) {
        light->timer += 5.0f; // Add 5 extra seconds
    }
}

// GPU kernel to calculate traffic flow statistics
__global__ void calculateFlowMetrics(TrafficData* traffic, float* avg_flow, 
                                     float* max_congestion, int grid_size) {
    __shared__ float shared_flow[256];
    __shared__ float shared_congestion[256];
    
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int tid = threadIdx.x;
    
    float local_flow = 0.0f;
    float local_max = 0.0f;
    
    if (idx < grid_size * grid_size) {
        int x = idx / grid_size;
        int y = idx % grid_size;
        
        for (int p = 0; p < PHASES; p++) {
            local_flow += traffic->flow_rate[x][y][p];
        }
        local_max = traffic->congestion[x][y];
    }
    
    shared_flow[tid] = local_flow;
    shared_congestion[tid] = local_max;
    __syncthreads();
    
    // Parallel reduction
    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            shared_flow[tid] += shared_flow[tid + s];
            shared_congestion[tid] = fmaxf(shared_congestion[tid], shared_congestion[tid + s]);
        }
        __syncthreads();
    }
    
    if (tid == 0) {
        atomicAdd(avg_flow, shared_flow[0]);
        atomicMax((int*)max_congestion, __float_as_int(shared_congestion[0]));
    }
}

// Host function to initialize traffic lights
void initializeTrafficLights(TrafficLight* lights, int num_lights) {
    for (int i = 0; i < num_lights; i++) {
        lights[i].id = i;
        lights[i].x = i % GRID_SIZE;
        lights[i].y = i / GRID_SIZE;
        lights[i].state = (i % PHASES == 0) ? GREEN : RED;
        lights[i].phase = i % PHASES;
        lights[i].timer = 30.0f;
        lights[i].green_duration = 30.0f;
        lights[i].yellow_duration = 3.0f;
        
        // Initialize traffic density with random values
        for (int j = 0; j < PHASES; j++) {
            lights[i].traffic_density[j] = (float)rand() / RAND_MAX;
        }
        
        // Connect to neighboring lights
        lights[i].connected_lights[0] = (lights[i].y > 0) ? i - GRID_SIZE : -1; // North
        lights[i].connected_lights[1] = (lights[i].x < GRID_SIZE - 1) ? i + 1 : -1; // East
        lights[i].connected_lights[2] = (lights[i].y < GRID_SIZE - 1) ? i + GRID_SIZE : -1; // South
        lights[i].connected_lights[3] = (lights[i].x > 0) ? i - 1 : -1; // West
    }
}

// Host function to initialize traffic data
void initializeTrafficData(TrafficData* traffic) {
    for (int x = 0; x < GRID_SIZE; x++) {
        for (int y = 0; y < GRID_SIZE; y++) {
            for (int p = 0; p < PHASES; p++) {
                // Simulate traffic patterns
                traffic->flow_rate[x][y][p] = 0.3f + 0.4f * ((float)rand() / RAND_MAX);
            }
            traffic->congestion[x][y] = 0.0f;
        }
    }
}

int main(int argc, char** argv) {
    printf("=== City Traffic Light Synchronization System (HIP) ===\n\n");
    
    int num_lights = GRID_SIZE * GRID_SIZE;
    size_t light_size = num_lights * sizeof(TrafficLight);
    size_t traffic_size = sizeof(TrafficData);
    
    // Host memory allocation
    TrafficLight* h_lights = (TrafficLight*)malloc(light_size);
    TrafficData* h_traffic = (TrafficData*)malloc(traffic_size);
    
    // Initialize data
    initializeTrafficLights(h_lights, num_lights);
    initializeTrafficData(h_traffic);
    
    // Device memory allocation
    TrafficLight* d_lights;
    TrafficData* d_traffic;
    float* d_avg_flow;
    float* d_max_congestion;
    
    hipMalloc(&d_lights, light_size);
    hipMalloc(&d_traffic, traffic_size);
    hipMalloc(&d_avg_flow, sizeof(float));
    hipMalloc(&d_max_congestion, sizeof(float));
    
    // Copy data to device
    hipMemcpy(d_lights, h_lights, light_size, hipMemcpyHostToDevice);
    hipMemcpy(d_traffic, h_traffic, traffic_size, hipMemcpyHostToDevice);
    
    // Kernel launch parameters
    int block_size = 256;
    int grid_size = (num_lights + block_size - 1) / block_size;
    
    printf("Managing %d traffic lights in %dx%d grid\n", num_lights, GRID_SIZE, GRID_SIZE);
    printf("Block size: %d, Grid size: %d\n\n", block_size, grid_size);
    
    // Simulation parameters
    float delta_time = 0.1f;  // 100ms update interval
    float simulation_time = 300.0f; // 5 minutes
    int iterations = (int)(simulation_time / delta_time);
    
    printf("Running simulation for %.0f seconds...\n", simulation_time);
    
    // Main simulation loop
    for (int iter = 0; iter < iterations; iter++) {
        // Step 1: Update traffic light states
        hipLaunchKernelGGL(updateTrafficLights, grid_size, block_size, 0, 0,
                          d_lights, num_lights, delta_time);
        
        // Step 2: Detect congestion (every second)
        if (iter % 10 == 0) {
            hipLaunchKernelGGL(detectCongestion, grid_size, block_size, 0, 0,
                              d_lights, d_traffic, num_lights, 2.5f);
        }
        
        // Step 3: Optimize green durations (every 10 seconds)
        if (iter % 100 == 0) {
            hipLaunchKernelGGL(optimizeGreenDurations, grid_size, block_size, 0, 0,
                              d_lights, d_traffic, num_lights, 20.0f, 60.0f);
        }
        
        // Step 4: Synchronize for green wave (every 30 seconds)
        if (iter % 300 == 0) {
            hipLaunchKernelGGL(synchronizeGreenWave, grid_size, block_size, 0, 0,
                              d_lights, num_lights, 15.0f, 200.0f);
        }
        
        // Step 5: Calculate metrics (every minute)
        if (iter % 600 == 0) {
            float zero = 0.0f;
            hipMemcpy(d_avg_flow, &zero, sizeof(float), hipMemcpyHostToDevice);
            hipMemcpy(d_max_congestion, &zero, sizeof(float), hipMemcpyHostToDevice);
            
            hipLaunchKernelGGL(calculateFlowMetrics, grid_size, block_size, 0, 0,
                              d_traffic, d_avg_flow, d_max_congestion, GRID_SIZE);
            
            float h_avg_flow, h_max_congestion;
            hipMemcpy(&h_avg_flow, d_avg_flow, sizeof(float), hipMemcpyDeviceToHost);
            hipMemcpy(&h_max_congestion, d_max_congestion, sizeof(float), hipMemcpyDeviceToHost);
            
            printf("[t=%.0fs] Avg flow: %.2f, Max congestion: %.2f\n", 
                   iter * delta_time, h_avg_flow / num_lights, h_max_congestion);
        }
    }
    
    // Copy results back
    hipMemcpy(h_lights, d_lights, light_size, hipMemcpyDeviceToHost);
    
    // Display sample results
    printf("\n=== Final Traffic Light States (Sample) ===\n");
    for (int i = 0; i < 10; i++) {
        const char* state_str[] = {"RED", "YELLOW", "GREEN"};
        printf("Light %d (%d,%d): %s, Phase: %d, Timer: %.1fs, Green: %.1fs\n",
               h_lights[i].id, h_lights[i].x, h_lights[i].y,
               state_str[h_lights[i].state], h_lights[i].phase,
               h_lights[i].timer, h_lights[i].green_duration);
    }
    
    // Cleanup
    hipFree(d_lights);
    hipFree(d_traffic);
    hipFree(d_avg_flow);
    hipFree(d_max_congestion);
    free(h_lights);
    free(h_traffic);
    
    printf("\nSimulation complete!\n");
    
    return 0;
}
