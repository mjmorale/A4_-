/*
============================================================================
Filename    : algorithm.c
Author      : Your name goes here
SCIPER      : Your SCIPER number
============================================================================
*/

#include <iostream>
#include <iomanip>
#include <sys/time.h>
#include <cuda_runtime.h>
using namespace std;

// CPU Baseline
void array_process(double *input, double *output, int length, int iterations)
{
    double *temp;

    for(int n=0; n<(int) iterations; n++)
    {
        for(int i=1; i<length-1; i++)
        {
            for(int j=1; j<length-1; j++)
            {
                output[(i)*(length)+(j)] = (input[(i-1)*(length)+(j-1)] +
                                            input[(i-1)*(length)+(j)]   +
                                            input[(i-1)*(length)+(j+1)] +
                                            input[(i)*(length)+(j-1)]   +
                                            input[(i)*(length)+(j)]     +
                                            input[(i)*(length)+(j+1)]   +
                                            input[(i+1)*(length)+(j-1)] +
                                            input[(i+1)*(length)+(j)]   +
                                            input[(i+1)*(length)+(j+1)] ) / 9;

            }
        }
        output[(length/2-1)*length+(length/2-1)] = 1000;
        output[(length/2)*length+(length/2-1)]   = 1000;
        output[(length/2-1)*length+(length/2)]   = 1000;
        output[(length/2)*length+(length/2)]     = 1000;

        temp = input;
        input = output;
        output = temp;
    }
}


__global__
void gpu_calculation(double* input, double* output, int length)
{   
    unsigned int x = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int y = blockIdx.y * blockDim.y + threadIdx.y;
    unsigned int index = y * length + x;
    
    if(x == length / 2 - 1 && y == length / 2 - 1) {
        return;
    }
    if(x == length / 2 && y == length / 2 - 1) {
        return;
    }
    if(x == length / 2 - 1 && y == length / 2) {
        return;
    }
    if(x == length / 2 && y == length / 2) {
        return;
    }

    if( (x > 0) && (x < length - 1) && (y > 0) && (y < length - 1) ) 
    {
        output[index] = (input[(x-1)*(length)+(y-1)] +
                        input[(x-1)*(length)+(y)]   +
                        input[(x-1)*(length)+(y+1)] +
                        input[(x)*(length)+(y-1)]   +
                        input[(x)*(length)+(y)]     +
                        input[(x)*(length)+(y+1)]   +
                        input[(x+1)*(length)+(y-1)] +
                        input[(x+1)*(length)+(y)]   +
                        input[(x+1)*(length)+(y+1)]) / 9;
            
    }
    
}

// GPU Optimized function
void GPU_array_process(double *input, double *output, int length, int iterations)
{
    //Cuda events for calculating elapsed time
    cudaEvent_t cpy_H2D_start, cpy_H2D_end, comp_start, comp_end, cpy_D2H_start, cpy_D2H_end;
    cudaEventCreate(&cpy_H2D_start);
    cudaEventCreate(&cpy_H2D_end);
    cudaEventCreate(&cpy_D2H_start);
    cudaEventCreate(&cpy_D2H_end);
    cudaEventCreate(&comp_start);
    cudaEventCreate(&comp_end);

    /* Preprocessing goes here */
    double* gpu_input;
    double* gpu_output;
    size_t size = length*length*sizeof(double);
    dim3 nbrThreads(8,8);
    dim3 nbrBlocks(length/8+1, length/8+1);
    cudaEventRecord(cpy_H2D_start);
    /* Copying array from host to device goes here */
    cudaMalloc((void**)&gpu_input, size);
    cudaMalloc((void**)&gpu_output, size);
    cudaMemcpy((void*)gpu_input, (void*)input,size, cudaMemcpyHostToDevice);
    cudaDeviceSynchronize();
    cudaMemcpy((void*)gpu_output, (void*)output,size, cudaMemcpyHostToDevice);
    cudaDeviceSynchronize();

    cudaEventRecord(cpy_H2D_end);
    cudaEventSynchronize(cpy_H2D_end);

    //Copy array from host to device
    cudaEventRecord(comp_start);
    /* GPU calculation goes here */
    for(int i = 0; i < iterations-1; i++)
    {
        gpu_calculation<<<nbrBlocks,nbrThreads>>>(gpu_input, gpu_output, length);
        cudaDeviceSynchronize();
        double* temp = gpu_output;
        gpu_output = gpu_input;
        gpu_input = temp;

    }
    gpu_calculation<<<nbrBlocks,nbrThreads>>>(gpu_input, gpu_output, length);

    cudaEventRecord(comp_end);
    cudaEventSynchronize(comp_end);

    cudaEventRecord(cpy_D2H_start);
    /* Copying array from device to host goes here */
    cudaMemcpy((void*)output, (void*)gpu_output,size, cudaMemcpyDeviceToHost);

    cudaEventRecord(cpy_D2H_end);
    cudaEventSynchronize(cpy_D2H_end);

    /* Postprocessing goes here */
    cudaFree(gpu_input);
    cudaFree(gpu_output);
    float time;
    cudaEventElapsedTime(&time, cpy_H2D_start, cpy_H2D_end);
    cout<<"Host to Device MemCpy takes "<<setprecision(4)<<time/1000<<"s"<<endl;

    cudaEventElapsedTime(&time, comp_start, comp_end);
    cout<<"Computation takes "<<setprecision(4)<<time/1000<<"s"<<endl;

    cudaEventElapsedTime(&time, cpy_D2H_start, cpy_D2H_end);
    cout<<"Device to Host MemCpy takes "<<setprecision(4)<<time/1000<<"s"<<endl;
}