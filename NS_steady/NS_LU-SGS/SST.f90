module SST
    
    use Grid_info
    
    implicit none

    real(8),allocatable:: U_SST(:,:) , U_av_SST(:,:)
    
    real(8),allocatable:: W_SST(:,:)
    
    
    real(8),allocatable:: Q_SST(:,:),dQdW_SST(:,:)
    
    real(8),allocatable:: Grad_UT(:,:,:),Grad_W_SST(:,:,:),Fc_SST(:,:),Fv_SST(:,:),Dissi_SST(:,:),Rsi_SST(:,:)
    
    
    real(8),parameter::C1_SST =1.0,C2_SST = 5.0, L_SST = 20.0 
    real(8),parameter::a1_SST = 0.31,beta_star_SST = 0.09 , kapa_SST = 0.41
    
    real(8),parameter::sigma_K1_SST = 0.85 , sigma_omg1_SST = 0.5 , beta1_SST=0.075  , Cw1_SST = 0.533
    real(8),parameter::sigma_K2_SST = 1.0  , sigma_omg2_SST = 0.856 , beta2_SST=0.0828 , Cw2_SST = 0.440  
    
    real(8),allocatable::sigma_K_SST(:), sigma_omg_SST(:), beta_SST(:), Cw_SST(:) 
    real(8),allocatable::f2_SST(:)
     
contains    
         
!  turbulent  model--kw-SST
   include "Allocate_memory_SST.f90"
   include "Mean_edge_SST.f90"
   include "con_flux_SST.f90"
   include "Art_dissipation_SST.f90"
   include "Gradient_SST.f90"
   include "Vis_flux_SST.f90"
   include "Resi_SST.f90"
   include "getMut_SST.f90"
   
   !include "LU_SGS_SST.f90"
end module


    