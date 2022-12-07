!> To generate cuda_blas.o
!> nvfortran -cuda -cudalib=cusparse,cusolver,cublas -Mpreprocess -C -traceback cuda_math.cuf
!> written by QSWu on Nov 18 2022 at IOP CAS, Beijing
!> Email: quansheng.wu@iphy.ac.cn or wuquansheng@gmail.com
!> tested with CUDA Toolkit v11.8  CUDA 22.5

subroutine cusparse_zcsrmv_in(ndim, nnz, x, iA, jA, matA, y)
    use cudafor
    use cusparse
    use cucsrmv_module
    use para, only : time_total_debug
    use iso_c_binding
    implicit none

    integer, parameter :: dp=kind(1d0)
    !> leading dimension of matrix matA
    integer, intent(in) :: ndim

    !> number of non-zeros entries of matrix matA
    integer, intent(in) :: nnz

    !> row index, column index, and values of matA
    !> ia and ja are one based.
    integer, intent(in) :: ia(ndim+1)
    integer, intent(in) :: ja(nnz)
    complex(dp), intent(in) :: matA(nnz)

    !> a dense vector
    complex(dp), intent(in) :: x(ndim)
    complex(dp), intent(out) :: y(ndim)

    complex(dp) :: alpha=1.0, beta=0.0

    real(dp) :: time1, time2

    integer*8 :: buffersize
    !> allocate memory on device, this works if compiled with CUDA Fortran
    !> compiler such as nvfortran
   !istatus= cudaMalloc(d_x, sizeof(x))
   !istatus= cudaMalloc(d_y, sizeof(y))
   !istatus= cudaMalloc(d_rowIdx, sizeof(ia))
   !istatus= cudaMalloc(d_colIdx, sizeof(ja))
   !istatus= cudaMalloc(d_matA, sizeof(matA))

   !call now(time1)
    y=0d0
    !> copy the data from host (CPU) to device (GPU)
    !d_x= x; d_rowIdx= ia; d_colIdx= ja; d_matA= matA
    d_x= x; 
   !call now(time2)
   !time_total_debug= time_total_debug+ time2- time1
    !istatus= cudaMemcpy(d_x, x, ndim, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_y, y, ndim, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_rowIdx, ia, ndim+1, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_colIdx, ja, nnz, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_matA, matA, nnz, cudaMemcpyHostToDevice)


    !> CUDA_C_64F  =  5, /* complex as a pair of double numbers */
    !> CUSPARSE_INDEX_32I = 2, ///< 32-bit signed integer for matrix/vector
    !> indices>
    istatus= cusparseCreateCsr(matrix, ndim, ndim, nnz, d_rowIdx, d_colIdx, d_matA,&
       CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I, CUSPARSE_INDEX_BASE_ONE, CUDA_C_64F)

    istatus= cusparseCreateDnVec(vecX, ndim, d_x, CUDA_C_64F)
    istatus= cusparseCreateDnVec(vecY, ndim, d_y, CUDA_C_64F)

    buffersize= 0
    istatus= cusparseSpMV_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, &
       alpha, matrix, vecX, beta, vecY, CUDA_C_64F, CUSPARSE_SPMV_ALG_DEFAULT, buffersize)
    istatus= cudaMalloc(buffer,buffersize)

    !> perform y=A*x on device
    istatus= cusparseSpMV(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, alpha, &
       matrix, vecX, beta, vecY, CUDA_C_64F, CUSPARSE_SPMV_ALG_DEFAULT, buffer)


    !> copy the data from device back to host
    y=d_y
    !istatus= cudaMemcpy(y, d_y, ndim, cudaMemcpyDeviceToHost)
    istatus= cudaFree(buffer)

    return
end subroutine cusparse_zcsrmv_in

   

subroutine cusparse_zcoomv(ndim, nnz, x, iA, jA, matA, y)
    use cudafor
    use cusparse
    use iso_c_binding

    implicit none

    integer, parameter :: dp=kind(1d0)

    !> leading dimension of matrix matA
    integer, intent(in) :: ndim

    !> number of non-zeros entries of matrix matA
    integer, intent(in) :: nnz

    !> row index, column index, and values of matA
    !> ia and ja are one based.
    integer, intent(in) :: ia(nnz)
    integer, intent(in) :: ja(nnz)
    complex(dp), intent(in) :: matA(nnz)

    !> a dense vector
    complex(dp), intent(in) :: x(ndim)
    complex(dp), intent(out) :: y(ndim)

    integer :: istatus
    complex(dp) :: alpha=1.0, beta=0.0

    integer*8 :: buffersize

    !> define device variables
    integer, allocatable, device :: buffer(:)
    complex(dp), allocatable, device :: d_x(:), d_matA(:), d_y(:)
    integer, allocatable, device :: d_rowIdx(:), d_colIdx(:), d_csrRowPtr(:)

    type(cusparseHandle) :: handle
    type(cusparseSpMatDescr) :: matrix
    type(cusparseDnVecDescr) :: vecX, vecY

    !> allocate memory on device, this works if compiled with CUDA Fortran
    !> compiler such as nvfortran
    !allocate(d_x(ndim), d_y(ndim), d_csrRowPtr(ndim+1))
    !allocate(d_rowIdx(nnz), d_colIdx(nnz), d_matA(nnz))
    istatus= cudaMalloc(d_x, sizeof(x))
    istatus= cudaMalloc(d_y, sizeof(y))
    istatus= cudaMalloc(d_csrRowPtr, (ndim+1)*sizeof(ndim))
    istatus= cudaMalloc(d_colIdx, sizeof(ia))
    istatus= cudaMalloc(d_rowIdx, sizeof(ja))
    istatus= cudaMalloc(d_matA, sizeof(matA))

    y=0d0
    !> copy the data from host (CPU) to device (GPU)
    !> d_x= x; d_rowIdx= ia; d_colIdx= ja; d_matA= matA; d_y= y
    istatus= cudaMemcpy(d_x, x, ndim, cudaMemcpyHostToDevice)
    istatus= cudaMemcpy(d_y, y, ndim, cudaMemcpyHostToDevice)
    istatus= cudaMemcpy(d_rowIdx, ia, nnz, cudaMemcpyHostToDevice)
    istatus= cudaMemcpy(d_colIdx, ja, nnz, cudaMemcpyHostToDevice)
    istatus= cudaMemcpy(d_matA, matA, nnz, cudaMemcpyHostToDevice)

    istatus=cusparseCreate(handle)

    !> convert coo to csr format on device
    istatus=cusparseXcoo2csr(handle, d_rowIdx, nnz, ndim, d_csrRowPtr, CUSPARSE_INDEX_BASE_ONE)

    !> CUDA_C_64F  =  5, /* complex as a pair of double numbers */
    !> CUSPARSE_INDEX_32I = 2, ///< 32-bit signed integer for matrix/vector
    !> indices>
    istatus=cusparseCreateCsr(matrix, ndim, ndim, nnz, d_csrRowPtr, d_colIdx, d_matA,&
       CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I, CUSPARSE_INDEX_BASE_ONE, CUDA_C_64F)

    istatus=cusparseCreateDnVec(vecX, ndim, d_x, CUDA_C_64F)
    istatus=cusparseCreateDnVec(vecY, ndim, d_y, CUDA_C_64F)

    buffersize= 0
    istatus=cusparseSpMV_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, &
       alpha, matrix, vecX, beta, vecY, CUDA_C_64F, CUSPARSE_SPMV_ALG_DEFAULT, buffersize)
    istatus=cudaMalloc(buffer,buffersize)

    !> perform y=A*x on device
    istatus=cusparseSpMV(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, alpha, &
       matrix, vecX, beta, vecY, CUDA_C_64F, CUSPARSE_SPMV_ALG_DEFAULT, buffer)

    !> copy the data from device back to host
    !> y=d_y
    istatus= cudaMemcpy(y, d_y, ndim, cudaMemcpyDeviceToHost)

    istatus=cudaFree(buffer)
    istatus=cusparseDestroy(handle)
    istatus=cusparseDestroyDnVec(vecX)
    istatus=cusparseDestroyDnVec(vecY)
    istatus=cusparseDestroySpMat(matrix)

    istatus=cudaFree(d_colIdx)
    istatus=cudaFree(d_csrRowPtr)
    istatus=cudaFree(d_matA)
    istatus=cudaFree(d_rowIdx)
    istatus=cudaFree(d_x)
    istatus=cudaFree(d_y)

    return
end subroutine cusparse_zcoomv

!> 
!> A subroutine performs y=A*x
!> A is  CSR sparse format stored, and the dimension is (ndim,ndim)
!> 
!> written by QSWu on Nov 18 2022 at IOP CAS, Beijing
!> Email: quansheng.wu@iphy.ac.cn or wuquansheng@gmail.com
!> tested with CUDA Toolkit v11.8  CUDA 22.5
subroutine cusparse_zcsrmv(ndim, nnz, x, iA, jA, matA, y)
    use cudafor
    use cusparse
    use iso_c_binding

    implicit none

    integer, parameter :: dp=kind(1d0)

    !> leading dimension of matrix matA
    integer, intent(in) :: ndim

    !> number of non-zeros entries of matrix matA
    integer, intent(in) :: nnz

    !> row index, column index, and values of matA
    !> ia and ja are one based.
    integer, intent(in) :: ia(ndim+1)
    integer, intent(in) :: ja(nnz)
    complex(dp), intent(in) :: matA(nnz)

    !> a dense vector
    complex(dp), intent(in) :: x(ndim)
    complex(dp), intent(out) :: y(ndim)

    integer :: istatus
    complex(dp) :: alpha=1.0, beta=0.0

    integer*8 :: buffersize

    !> define device variables
    integer, allocatable, device :: buffer(:)
    integer, allocatable, device :: d_rowIdx(:), d_colIdx(:)
    complex(dp), allocatable, device :: d_x(:), d_matA(:), d_y(:)

    type(cusparseHandle) :: handle
    type(cusparseSpMatDescr) :: matrix
    type(cusparseDnVecDescr) :: vecX, vecY

    !> allocate memory on device, this works if compiled with CUDA Fortran
    !> compiler such as nvfortran
    allocate(d_x(ndim), d_y(ndim))
    allocate(d_rowIdx(ndim+1), d_colIdx(nnz), d_matA(nnz))
   !istatus= cudaMalloc(d_x, sizeof(x))
   !istatus= cudaMalloc(d_y, sizeof(y))
   !istatus= cudaMalloc(d_rowIdx, sizeof(ia))
   !istatus= cudaMalloc(d_colIdx, sizeof(ja))
   !istatus= cudaMalloc(d_matA, sizeof(matA))

    y=0d0
    !> copy the data from host (CPU) to device (GPU)
    d_x= x; d_rowIdx= ia; d_colIdx= ja; d_matA= matA; d_y= y
    !istatus= cudaMemcpy(d_x, x, ndim, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_y, y, ndim, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_rowIdx, ia, ndim+1, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_colIdx, ja, nnz, cudaMemcpyHostToDevice)
    !istatus= cudaMemcpy(d_matA, matA, nnz, cudaMemcpyHostToDevice)

    istatus= cusparseCreate(handle)

    !> CUDA_C_64F  =  5, /* complex as a pair of double numbers */
    !> CUSPARSE_INDEX_32I = 2, ///< 32-bit signed integer for matrix/vector
    !> indices>
    istatus= cusparseCreateCsr(matrix, ndim, ndim, nnz, d_rowIdx, d_colIdx, d_matA,&
       CUSPARSE_INDEX_32I, CUSPARSE_INDEX_32I, CUSPARSE_INDEX_BASE_ONE, CUDA_C_64F)

    istatus= cusparseCreateDnVec(vecX, ndim, d_x, CUDA_C_64F)
    istatus= cusparseCreateDnVec(vecY, ndim, d_y, CUDA_C_64F)

    buffersize= 0
    istatus= cusparseSpMV_bufferSize(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, &
       alpha, matrix, vecX, beta, vecY, CUDA_C_64F, CUSPARSE_SPMV_ALG_DEFAULT, buffersize)
    istatus= cudaMalloc(buffer,buffersize)

    !> perform y=A*x on device
    istatus= cusparseSpMV(handle, CUSPARSE_OPERATION_NON_TRANSPOSE, alpha, &
       matrix, vecX, beta, vecY, CUDA_C_64F, CUSPARSE_SPMV_ALG_DEFAULT, buffer)

    !> copy the data from device back to host
    y=d_y
    !istatus= cudaMemcpy(y, d_y, ndim, cudaMemcpyDeviceToHost)

    istatus= cusparseDestroy(handle)
    istatus= cusparseDestroyDnVec(vecX)
    istatus= cusparseDestroyDnVec(vecY)
    istatus= cusparseDestroySpMat(matrix)

    deallocate(d_x, d_y, d_matA, d_rowIdx, d_colIdx)
    istatus= cudaFree(buffer)
   !istatus= cudaFree(d_rowIdx)
   !istatus= cudaFree(d_colIdx)
   !istatus= cudaFree(d_x)
   !istatus= cudaFree(d_y)
   !istatus= cudaFree(d_matA)

    return
end subroutine cusparse_zcsrmv

!> A subroutine computes eigenvalues and eigenvectors of a symmetric or
!> Hermitian ndim x ndim matrix Amat(ndim, ndim)
!> input/output : Amat(ndim, ndim), Amat will be overwritten as the eigenvectors on output
!> use cusolver on GPU device
subroutine cusolver_zheev(ndim, Amat, eigval)

   use cudafor
   use cusolverDn
   implicit none

   integer, parameter :: dp=kind(1d0)
   integer, intent(in) :: ndim
   complex(dp), intent(inout) :: Amat(ndim, ndim)
   real(dp), intent(out) :: eigval(ndim)

   integer :: istatus, lwork, info

   !> variables related to GPU
   type(cusolverDnHandle) :: handle
   integer, device :: devinfo
   complex(dp), device, allocatable :: d_A(:)
   real(dp), device, allocatable :: d_eigval(:)
   complex(dp), device, allocatable :: d_workspace(:)

   integer :: jobz, uplo

   jobz= CUSOLVER_EIG_MODE_VECTOR  ! compute eigenvalues and eigenvectors.
   uplo= CUBLAS_FILL_MODE_UPPER

   !> step 1: create cusolver handle 
   istatus= cusolverDnCreate(handle)
  
   !> step 2: allocate memory on device and copy data from host to device
   !allocate(d_A(ndim, ndim), d_eigval(ndim))
   istatus= cudaMalloc(d_A, sizeof(Amat))
   istatus= cudaMalloc(d_eigval, sizeof(eigval))

   !> d_A= Amat
   istatus= cudaMemcpy(d_A, Amat, ndim*ndim, cudaMemcpyHostToDevice)

   !> step 3: query working space of getrf 
   istatus= cusolverDnZheevd_buffersize(handle, jobz, uplo, ndim, d_A, ndim, d_eigval, lwork)
   !allocate(d_workspace(lwork))
   istatus= cudaMalloc(d_workspace, lwork)

   istatus= cusolverDnZheevd(handle, &
          jobz, uplo, ndim, d_A, ndim, d_eigval, d_workspace, lwork, devinfo)

   if (istatus/=0) print *, 'ERROR: something wrong with cusolverDnZheevd on GPU'

   !> step 4: copy data from device back to host
   !> eigval= d_eigval
   !> Amat= d_A
   istatus= cudaMemcpy(Amat, d_A, ndim*ndim, cudaMemcpyDeviceToHost)
   istatus= cudaMemcpy(eigval, d_eigval, ndim, cudaMemcpyDeviceToHost)

   !> step 5: free memory on GPU
   !deallocate(d_A, d_eigval, d_workspace)
   istatus= cusolverDnDestroy(handle)
   istatus= cudaFree(d_A)
   istatus= cudaFree(d_eigval)
   istatus= cudaFree(d_workspace)

   return
end subroutine cusolver_zheev


!> subroutine to perform the inverse of a matrix Amat(ndim, ndim)
!> input/output : Amat(ndim, ndim), Amat will be overwritten on output
!> use cusolver on GPU device
subroutine cusolver_zgesv(ndim, Amat)

   use cudafor
   use cusolverDn
   implicit none

   integer, parameter :: dp=kind(1d0)
   integer, intent(in) :: ndim
   complex(dp), intent(inout) :: Amat(ndim, ndim)
   complex(dp) :: A_t(ndim, ndim)

   integer :: trans, istatus, lwork, i, info
   integer, allocatable :: ipiv(:)
   complex(dp), allocatable :: Bmat(:, :)

   !> variables related to GPU
   type(cusolverDnHandle) :: handle
   integer, device :: devinfo
   integer, device, allocatable :: d_devipiv(:)
   complex(dp), device, allocatable :: d_A(:)
   complex(dp), device, allocatable :: d_B(:)
   complex(dp), device, allocatable :: d_workspace(:)

   allocate(ipiv(ndim))
   ipiv= 0

   !> step 1: create cusolver handle 
   istatus= cusolverDnCreate(handle)
  
   !> define the Bmat to be a unitary matrix as an input of cusolverDnZgetrs
   allocate(Bmat(ndim, ndim))
   Bmat= 0d0
   do i=1, ndim
      Bmat(i, i)= 1d0
   enddo

   !> step 2: allocate memory on device and copy data from host to device
   !allocate(d_A(ndim, ndim), d_devipiv(ndim), d_B(ndim, ndim))
   istatus= cudaMalloc(d_A, sizeof(Amat))
   istatus= cudaMalloc(d_B, sizeof(Amat))
   istatus= cudaMalloc(d_devipiv, sizeof(ipiv))

   !> d_A= Amat; d_devipiv= ipiv; d_B= Bmat
   istatus= cudaMemcpy(d_A, Amat, ndim*ndim, cudaMemcpyHostToDevice)
   istatus= cudaMemcpy(d_B, Bmat, ndim*ndim, cudaMemcpyHostToDevice)
   istatus= cudaMemcpy(d_devipiv, ipiv, ndim, cudaMemcpyHostToDevice)

   !> step 3: query working space of getrf 
   istatus= cusolverDnZgetrf_bufferSize(handle, ndim, ndim, d_A, ndim, lwork)
   !allocate(d_workspace(lwork))
   istatus= cudaMalloc(d_workspace, lwork)

   !> cusolverDnZgetrf computes the LU factorization of a general mxn matrix
   istatus= cusolverDnZgetrf(handle, &
         ndim, ndim, d_A, ndim, d_workspace, d_devipiv, devinfo)

   !> cusolverDnZgetrs solves the system of linear equations A*x= b resulting from the LU
   ! factorization of a matrix using cusolverDnZgetrf
   istatus= cusolverDnZgetrs(handle, &
          CUBLAS_OP_N, ndim, ndim, d_A, ndim, d_devipiv, d_B, ndim, devinfo)

   if (istatus/=0) print *, 'ERROR: something wrong with zgesv on GPU'

   !> step 4: copy data from device back to host
   !> Amat= d_B
   istatus= cudaMemcpy(Amat, d_B, ndim*ndim, cudaMemcpyDeviceToHost)

   !> free memory on GPU
   istatus=cusolverDnDestroy(handle)
   istatus= cudaFree(d_A)
   istatus= cudaFree(d_B)
   istatus= cudaFree(d_devipiv)
   istatus= cudaFree(d_workspace)
   !deallocate(d_A, d_B, d_workspace, d_devipiv)
   deallocate(Bmat, ipiv)

   return
end subroutine cusolver_zgesv

!> A subroutine to perform matrix-matrix multiplication C=A*B on GPU device
!> A, B and C are double complex matrices, whose dimensionality is (ndim, ndim).
subroutine mat_mul_cuda_z(ndim, A, B, C)
   use cudafor
   use cublas
   use cusparse
   use iso_c_binding

   implicit none

   integer, parameter :: dp= kind(1d0)
   integer, intent(in) :: ndim
   complex(dp), intent(in)  :: A(ndim, ndim)
   complex(dp), intent(in)  :: B(ndim, ndim)
   complex(dp), intent(out) :: C(ndim, ndim)

   integer :: istatus
   integer*8 :: isize
   complex(dp) :: alpha, beta

   !> variables on GPU device
   type(cublasHandle) :: handle
   complex(dp), device, allocatable :: d_A(:)
   complex(dp), device, allocatable :: d_B(:)
   complex(dp), device, allocatable :: d_C(:)

   alpha= 1d0
   beta = 0d0

   !> copy data from host to device
  !allocate(d_A(ndim, ndim), d_B(ndim, ndim), d_C(ndim, ndim))
   istatus= cudaMalloc(d_A, sizeof(A))
   istatus= cudaMalloc(d_B, sizeof(B))
   istatus= cudaMalloc(d_C, sizeof(C))

   !> d_A= A; d_B= B;
   istatus= cudaMemcpy(d_A, A, ndim*ndim, cudaMemcpyHostToDevice)
   istatus= cudaMemcpy(d_B, B, ndim*ndim, cudaMemcpyHostToDevice)

   istatus= cublasCreate(handle)
   istatus= cublasZgemm_v2(handle, CUBLAS_OP_N, CUBLAS_OP_N, ndim, ndim, ndim, &
      alpha, d_A, ndim, d_B, ndim, beta, d_C, ndim)

   !> copy data from device to host
   !> C= d_C
   istatus= cudaMemcpy(C, d_C, ndim*ndim, cudaMemcpyDeviceToHost)

   !> Free memory on device
   istatus= cublasDestroy(handle)
   !deallocate(d_A, d_B, d_C)
   istatus= cudaFree(d_A)
   istatus= cudaFree(d_B)
   istatus= cudaFree(d_C)

   return
end subroutine mat_mul_cuda_z


! ! compile it with
! !> nvfortran -cuda -cudalib=cusparse,cusolver,cublas -Mpreprocess -C -traceback cuda_math.cuf
! ! run it with 
! !  ./a.out
! !> modified by QSWu on Nov 17 2022
! !> tested with CUDA Toolkit v11.8  CUDA 22.5
! program product
!     use cudafor
!     use cusparse
!     use cucsrmv_module
!     use iso_c_binding
! 
!     implicit none
! 
!     complex(8),allocatable :: x(:), matA(:), y(:), x2(:)
!     integer*4,allocatable :: rowIdx(:), colIdx(:),csrRowPtr(:)
! 
!     integer*4 :: nx, nz, status, i
!     complex(8), allocatable :: matA_dense(:, :)
!     complex(8), allocatable :: matB_dense(:, :)
!     complex(8), allocatable :: matC_dense(:, :)

!     real(8), allocatable :: eigval(:)
! 
!     integer*4 :: start, end, countrate
!     complex(8) :: t
! 
!     nx=4
!     nz=9
! 
!     allocate(x(nx), y(nx), csrRowPtr(nx+1), x2(nx))
!     allocate(rowIdx(nz), colIdx(nz), matA(nz))
!     allocate(matA_dense(nx, nx))
!     allocate(matB_dense(nx, nx))
!     allocate(matC_dense(nx, nx))
!     allocate(eigval(nx))
! 
!     !> a standard matrix used in the example of cusparse library
!     !> https://github.com/NVIDIA/CUDALibrarySamples/tree/master/cuSPARSE/spmv_csr
!     rowIdx=(/0, 0, 0, 1, 2, 2, 2, 3, 3/)
!     csrRowPtr=(/0, 3, 4, 7, 9/)
!     colIdx=(/0, 2, 3, 1, 0, 2, 3, 1, 3/)
!     matA=(/1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0/)
!     x=(/1.0, 2.0, 3.0, 4.0/)
!     !> the results of y=A*x=(/19, 8, 51, 52/)
! 
!     rowIdx=rowIdx+1
!     colIdx=colIdx+1
!     csrRowPtr= csrRowPtr+1
! 
!     call cusparse_zcoomv(nx, nz, x, rowIdx, colIdx, matA, y)
!     print *, 'x:', x
!     print *, 'y:', y
! 
!     call cusparse_zcsrmv(nx, nz, x, csrRowPtr, colIdx, matA, y)
!     print *, 'x:', x
!     print *, 'y:', y
!
!     call cusparse_zcsrmv_allocate(nx, nz)
!     call cusparse_zcsrmv_in(nx, nz, x, csrRowPtr, colIdx, matA, y)
!     call cusparse_zcsrmv_deallocate
!     print *, 'x:', x
!     print *, 'y:', y
! 
! 
!     matA_dense(1, :)=(/0, 1, 0, 0/)
!     matA_dense(2, :)=(/1, 0, 1, 0/)
!     matA_dense(3, :)=(/0, 1, 0, 1/)
!     matA_dense(4, :)=(/0, 0, 1, 0/)
! 
!     print *, 'matA_dense'
!     do i=1, nx
!        write(*, '(100f8.2)')real(matA_dense(i, :))
!     enddo
!     call cusolver_zgesv(nx, matA_dense)
!     print *, 'inverse of matA_dense'
!     do i=1, nx
!        write(*, '(100f8.2)')real(matA_dense(i, :))
!     enddo
! 
!     !> gest for mat_mul_cuda_z
!     matB_dense= matA_dense
!     call mat_mul_cuda_z(nx, matA_dense, matB_dense, matC_dense)
!     print *, 'matC_dense=A*A'
!     do i=1, nx
!        write(*, '(100f8.2)')real(matC_dense(i, :))
!     enddo

!     !> get eigenvalue of A
!     matA_dense(1, :)=(/0, 1, 0, 0/)
!     matA_dense(2, :)=(/1, 0, 1, 0/)
!     matA_dense(3, :)=(/0, 1, 0, 1/)
!     matA_dense(4, :)=(/0, 0, 1, 0/)
!
!     call cusolver_zheev(nx, matA_dense, eigval)
!     print *, 'eigval:', eigval
! 
! end
