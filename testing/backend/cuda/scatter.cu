#include <unittest/unittest.h>
#include <thrust/scatter.h>
#include <thrust/execution_policy.h>


template<typename Iterator1, typename Iterator2, typename Iterator3>
__global__
void scatter_kernel(Iterator1 first, Iterator1 last, Iterator2 map_first, Iterator3 result)
{
  thrust::scatter(thrust::seq, first, last, map_first, result);
}


template<typename T>
void TestScatterDeviceSeq(const size_t n)
{
  const size_t output_size = std::min((size_t) 10, 2 * n);
  
  thrust::host_vector<T> h_input(n, (T) 1);
  thrust::device_vector<T> d_input(n, (T) 1);
  
  thrust::host_vector<unsigned int> h_map = unittest::random_integers<unsigned int>(n);
  
  for(size_t i = 0; i < n; i++)
  {
    h_map[i] =  h_map[i] % output_size;
  }
  
  thrust::device_vector<unsigned int> d_map = h_map;
  
  thrust::host_vector<T>   h_output(output_size, (T) 0);
  thrust::device_vector<T> d_output(output_size, (T) 0);
  
  thrust::scatter(h_input.begin(), h_input.end(), h_map.begin(), h_output.begin());
  scatter_kernel<<<1,1>>>(d_input.begin(), d_input.end(), d_map.begin(), d_output.begin());
  
  ASSERT_EQUAL(h_output, d_output);
}
DECLARE_VARIABLE_UNITTEST(TestScatterDeviceSeq);


template<typename Iterator1, typename Iterator2, typename Iterator3, typename Iterator4, typename Function>
__global__
void scatter_if_kernel(Iterator1 first, Iterator1 last, Iterator2 map_first, Iterator3 stencil_first, Iterator4 result, Function f)
{
  thrust::scatter_if(thrust::seq, first, last, map_first, stencil_first, result, f);
}


template<typename T>
struct is_even_scatter_if
{
  __host__ __device__ bool operator()(const T i) const { return (i % 2) == 0; }
};


template<typename T>
void TestScatterIfDeviceSeq(const size_t n)
{
  const size_t output_size = std::min((size_t) 10, 2 * n);
  
  thrust::host_vector<T> h_input(n, (T) 1);
  thrust::device_vector<T> d_input(n, (T) 1);
  
  thrust::host_vector<unsigned int> h_map = unittest::random_integers<unsigned int>(n);
  
  for(size_t i = 0; i < n; i++)
  {
    h_map[i] =  h_map[i] % output_size;
  }
  
  thrust::device_vector<unsigned int> d_map = h_map;
  
  thrust::host_vector<T>   h_output(output_size, (T) 0);
  thrust::device_vector<T> d_output(output_size, (T) 0);
  
  thrust::scatter_if(h_input.begin(), h_input.end(), h_map.begin(), h_map.begin(), h_output.begin(), is_even_scatter_if<unsigned int>());
  scatter_if_kernel<<<1,1>>>(d_input.begin(), d_input.end(), d_map.begin(), d_map.begin(), d_output.begin(), is_even_scatter_if<unsigned int>());
  
  ASSERT_EQUAL(h_output, d_output);
}
DECLARE_VARIABLE_UNITTEST(TestScatterIfDeviceSeq);


void TestScatterCudaStreams()
{
  typedef thrust::device_vector<int> Vector;
  typedef typename Vector::value_type T;

  Vector map(5);  // scatter indices
  Vector src(5);  // source vector
  Vector dst(8);  // destination vector

  map[0] = 6; map[1] = 3; map[2] = 1; map[3] = 7; map[4] = 2;
  src[0] = 0; src[1] = 1; src[2] = 2; src[3] = 3; src[4] = 4;
  dst[0] = 0; dst[1] = 0; dst[2] = 0; dst[3] = 0; dst[4] = 0; dst[5] = 0; dst[6] = 0; dst[7] = 0;

  cudaStream_t s;
  cudaStreamCreate(&s);

  thrust::scatter(thrust::cuda::par(s), src.begin(), src.end(), map.begin(), dst.begin());

  cudaStreamSynchronize(s);

  ASSERT_EQUAL(dst[0], 0);
  ASSERT_EQUAL(dst[1], 2);
  ASSERT_EQUAL(dst[2], 4);
  ASSERT_EQUAL(dst[3], 1);
  ASSERT_EQUAL(dst[4], 0);
  ASSERT_EQUAL(dst[5], 0);
  ASSERT_EQUAL(dst[6], 0);
  ASSERT_EQUAL(dst[7], 3);

  cudaStreamDestroy(s);
}
DECLARE_UNITTEST(TestScatterCudaStreams);


void TestScatterIfCudaStreams()
{
  typedef thrust::device_vector<int> Vector;
  typedef typename Vector::value_type T;
  
  Vector flg(5);  // predicate array
  Vector map(5);  // scatter indices
  Vector src(5);  // source vector
  Vector dst(8);  // destination vector
  
  flg[0] = 0; flg[1] = 1; flg[2] = 0; flg[3] = 1; flg[4] = 0;
  map[0] = 6; map[1] = 3; map[2] = 1; map[3] = 7; map[4] = 2;
  src[0] = 0; src[1] = 1; src[2] = 2; src[3] = 3; src[4] = 4;
  dst[0] = 0; dst[1] = 0; dst[2] = 0; dst[3] = 0; dst[4] = 0; dst[5] = 0; dst[6] = 0; dst[7] = 0;

  cudaStream_t s;
  cudaStreamCreate(&s);
  
  thrust::scatter_if(thrust::cuda::par(s), src.begin(), src.end(), map.begin(), flg.begin(), dst.begin());
  cudaStreamSynchronize(s);
  
  ASSERT_EQUAL(dst[0], 0);
  ASSERT_EQUAL(dst[1], 0);
  ASSERT_EQUAL(dst[2], 0);
  ASSERT_EQUAL(dst[3], 1);
  ASSERT_EQUAL(dst[4], 0);
  ASSERT_EQUAL(dst[5], 0);
  ASSERT_EQUAL(dst[6], 0);
  ASSERT_EQUAL(dst[7], 3);

  cudaStreamDestroy(s);
}
DECLARE_UNITTEST(TestScatterIfCudaStreams);
