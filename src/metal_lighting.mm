#include "light_shader.h"
#import <Metal/Metal.h>
#include <algorithm>
#include <vector>

namespace fireplace {
namespace {
struct Output {
  float red, green, blue, fire, facing;
};
NSString *const source = @R"metal(
#include <metal_stdlib>
using namespace metal;
struct Input { float px, py, pz, nx, ny, nz, vx, vy, vz, fuel, intensity; };
struct Output { float red, green, blue, fire, facing; };
kernel void shade(const device Input *inputs [[buffer(0)]],
                  device Output *out [[buffer(1)]], uint i [[thread_position_in_grid]]) {
  Input s = inputs[i];
  float3 toFire = float3(-s.px, -0.55f - s.py, -s.pz);
  float distance = max(0.001f, length(toFire));
  float facing = max(0.0f, dot(float3(s.nx,s.ny,s.nz), toFire) / distance);
  float fire = clamp(s.intensity, 0.0f, 1.0f) * (0.15f + 0.85f * facing) / (1.0f + distance * distance);
  float key = 0.55f + 0.45f * max(0.0f, dot(float3(s.vx,s.vy,s.vz), float3(-0.4f,0.8f,0.4472135955f)));
  float charFactor = 0.25f + 0.75f * clamp(s.fuel, 0.0f, 1.0f);
  float3 color = clamp(float3(0.72f, 0.43f, 0.21f) * key * charFactor + fire * float3(0.35f,0.12f,0.025f), 0.0f, 1.0f);
  out[i] = {color.r, color.g, color.b, fire, facing};
}
)metal";
} // namespace
void shade_wood_batch(const LightInput *inputs, ShadedLight *outputs,
                      unsigned count) {
  if (!count)
    return;
  static id<MTLDevice> device;
  static id<MTLCommandQueue> queue;
  static id<MTLComputePipelineState> pipeline;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    device = MTLCreateSystemDefaultDevice();
    if (!device)
      return;
    NSError *error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:source
                                                  options:nil
                                                    error:&error];
    if (!library) {
      NSLog(@"Metal lighting unavailable: %@", error);
      return;
    }
    id<MTLFunction> function = [library newFunctionWithName:@"shade"];
    if (!function)
      return;
    pipeline = [device newComputePipelineStateWithFunction:function
                                                     error:&error];
    if (!pipeline) {
      NSLog(@"Metal lighting unavailable: %@", error);
      return;
    }
    queue = [device newCommandQueue];
  });
  if (pipeline && queue) {
    id<MTLBuffer> in = [device newBufferWithBytes:inputs
                                           length:sizeof(LightInput) * count
                                          options:MTLResourceStorageModeShared];
    id<MTLBuffer> out =
        [device newBufferWithLength:sizeof(Output) * count
                            options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> command = [queue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
    if (in && out && command && encoder) {
      [encoder setComputePipelineState:pipeline];
      [encoder setBuffer:in offset:0 atIndex:0];
      [encoder setBuffer:out offset:0 atIndex:1];
      [encoder dispatchThreads:MTLSizeMake(count, 1, 1)
          threadsPerThreadgroup:MTLSizeMake(
                                    std::min<unsigned>(
                                        count,
                                        pipeline.maxTotalThreadsPerThreadgroup),
                                    1, 1)];
      [encoder endEncoding];
      [command commit];
      [command waitUntilCompleted];
      if (command.status == MTLCommandBufferStatusCompleted) {
        const auto *values = static_cast<const Output *>(out.contents);
        for (unsigned i = 0; i < count; ++i)
          outputs[i] = {{values[i].red, values[i].green, values[i].blue},
                        values[i].fire,
                        values[i].facing};
        return;
      }
    }
  }
  for (unsigned i = 0; i < count; ++i) {
    const auto &s = inputs[i];
    outputs[i] =
        shade_wood({0.72, 0.43, 0.21}, {s.px, s.py, s.pz}, {s.nx, s.ny, s.nz},
                   {s.vx, s.vy, s.vz}, s.fuel, s.intensity);
  }
}
} // namespace fireplace
