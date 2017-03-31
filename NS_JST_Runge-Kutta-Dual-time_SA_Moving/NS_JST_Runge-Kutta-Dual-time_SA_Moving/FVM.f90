module FVM              !finite volume method 
    !object:  get the steady or unsteady flow properties finally 
   
    use Control_para
    use Grid_info
    
    use  SA        !turbulence variables
    
    implicit none   
    real(8)::u_inf,v_inf,a_inf                        !incoming flow's velocities and sound velocity
    real(8),allocatable::U(:,:) ,U_av(:,:),&    !the oringinal variables of every cell
                         W(:,:)   , Wn(:,:) , Wn1(:,:),Q(:,:)  ,&                 !the conservative variables of every cell
                         W0(:,:)  , &                 !the zeroth step conservative variables
                         Rsi(:,:) , &                 !residual 
                         Fc(:,:)  , &                 !convective flux of every cell
                         alf(:)   ,  alf_v(:),&                 !spectral radius of every edge
                         Dissi(:,:)  ,D_last(:,:), &              !artificial dissipation of every cell
                         dt(:)      ,&                !time step of every cell 
                         Grad(:,:,:)  ,&
                         Fv(:,:), muL(:), muL_av(:) 
            
    !Moving
    real(8),allocatable::xy0(:,:),vector0(:,:),rij0(:,:),rR0(:,:),rL0(:,:),tij0(:,:)
   
    real(8),allocatable::U_Rot(:,:)
                        
      
contains

include "Read_flow.f90"
include "Rotation.f90"
include "Mean_edge.f90"
include "Con_flux.f90"
include "Art_dissipation.f90"

 !Turbulence ,to get muT
   include "Allocate_memory_Tur.f90"
   include "Mean_edge_Tur.f90"
   include "con_flux_Tur.f90"
   include "Art_dissipation_Tur.f90"
   include "Gradient_Tur.f90"
   include "Vis_flux_Tur.f90"
   include "SA_solver.f90"
   include "muT_cal.f90"
   
include "Gradient.f90"     
include "Vis_flux.f90"
  

include "Output.f90"
include "outputFreeFlow.f90"


subroutine Allocate_memory

   
    
    !allocate memory 
    allocate( U(5,ncells) )        !the primative variables            
   
    allocate( W(5,ncells) )        !the conserved variables
    
    allocate( Wn(5,ncells) )      
    allocate( Wn1(5,ncells) )       
    allocate( Q(5,ncells) )    
    
    allocate( W0(5,ncells) )     !it's needed for Runge_kutta method
     
    allocate( U_av(6,nedges) )     !the primative variable on the edges, the boundary conditon is used here 
    allocate( Grad(2,6,ncells) )   !the gradient of every cell,rou,u,v,w,p,T
    allocate( Fc(5,ncells) )       !the convective flux
    allocate( Dissi(5,ncells) )   ! the artificial dissipation
    allocate( D_last(5,ncells) ) 
    !time
    allocate( alf(nedges) )        !the spectrum radius of every edge
    allocate( alf_v(nedges) )    
    allocate( dt(ncells) )         ! the time  step
    
    !viscosity
    allocate( Fv(5,ncells) )       !the viscous flux
    allocate( muL(ncells) )
    allocate( muL_av(nedges) )     
  
    allocate( Rsi(5,ncells) )      !the residual
    
    !moving
    allocate( xy0(2,nnodes) )
    allocate( vector0(2,nedges) )
    allocate( rij0(2,nedges) ) 
    allocate( rR0(2,nedges) ) 
    allocate( rL0(2,nedges) )
    allocate( tij0(2,nedges) )
    
    allocate( U_Rot(2,nnodes) )
    
   

end subroutine

subroutine Flow_init      !initialize the flow field

    implicit none
   
    a_inf=sqrt(p_inf*gamma/rou_inf)
    u_inf=Ma_inf*a_inf*cosd(att)        
    v_inf=Ma_inf*a_inf*sind(att)
   
    
    W(1,:)=U(1,:)
    W(2,:)=U(1,:)*U(2,:)
    W(3,:)=U(1,:)*U(3,:)
    W(5,:)=U(5,:)/(gamma-1.0) + U(1,:)*(U(2,:)**2 + U(3,:)**2)/2.0   
    
    
    !turbulence conservative variable
    WT=U(1,:)*nuT
   
end subroutine
 
subroutine Solver          !the Solver
    implicit none
    integer::i,j
    integer::count
    integer::iter          !iterative variable
    integer::flag=0          !the variable to judge wheathe the mean density converges
    character(len=30):: filename!= "flow_info-.dat"
    real(8)::t_total = 0.0
    real(8)::omg
    real(8)::AoA,angular_rate
    
    write(*,*)  "Solver"
    
    call outputFreeFlow
    call Grid
    call Allocate_memory
    call Allocate_memory_Tur
    call Read_flow
    
    call Flow_init
    
    !-----------------------------------
    !geometry set
    !translate the grid to where the rotational center's coordinates are zero
    
   !geometry set
    vector0 = vector
    rij0 =rij
    rR0 = rR
    rL0 = rL
    tij0 = tij
    
    do i=1,nnodes
        xy0(:,i) = xy(:,i)-rot_cen(:)
    end do 
    
    !--------------------------------------
    
    Wn = W
    Wn1 = W
    
    WTn=WT
    WTn1=WT
    
    omg =  2.0*kr*Ma_inf*a_inf
    
    do i =1,phase   
        
        do iter =1,itermax
            
            t_total = t_total + dt_r
            AoA = att + att_ampl* sin( omg * t_total )
            angular_rate = omg * ( att_ampl/180*pi ) * cos( omg * t_total )   !change the unit angle to arc
          
            Wn1 = Wn
            Wn = W
            
            WTn1= WTn
            WTn = WT
            
            do j = 1,5
                Q(j,:) = 2.0/dt_r*vol*Wn(j,:) -1.0/2.0/dt_r*vol*Wn1(j,:)
            end do
            Q_WT = 2.0 /dt_r *vol*WTn -1.0/2/dt_r * vol*WTn1
            
          
            call Rotation(AoA,angular_rate)  !renew the node speed and coordinates
            
            do count=1,iter_inner
                write(*,*) count,iter,i
                write(*,*) "t:",t_total,"dt:",dt_r
                write(*,*) "AoA:",AoA

                call Runge_kutta
                call Converge(flag)
               
            end do
        
            write(filename,"(I2)") i
            
            filename = "flow_info-" // trim(filename)//".dat"
            call Output(filename) 
            write(*,*) "Output" 
            
        end do
    end do
    
     
end subroutine 

subroutine Runge_kutta        !Runge-kutta scheme
    implicit none
    integer::m                !the step number of Runge-kutta
    integer::mm               !the number of equations
    
    !write(*,*)   "Runge_kutta"
    !set w0 with the W
    W0 = W
    
    WT0 = WT
    
    do m = 1,Stage 
        
        call Mean_edge  
        muL =   1.45*( U(5,:)/R/U(1,:) ) **(3.0/2)/(U(5,:)/R/U(1,:) + 110.0) *1.0E-6
        muL_av = 1.45*U_av(6,:)**(3.0/2)/( U_av(6,:)+110.0 ) *1.0E-6
        call muT_cal
        
        call Con_flux  
        
        call Art_dissipation                     
        dt = CFL*vol/dt      !calculate the time step
    
        call Gradient
            
        call SA_solver(m)       !calculate the muT

        call Vis_flux
    
        if(m == 1)  then                 !calculate the dissipation and the time step only at the first stage 
             Rsi = Fc - Dissi -Fv       
        else
             Rsi =  Fc - (  beta(m)*Dissi + ( 1.0 - beta(m) ) * D_last  ) - Fv
        end if 
       
        D_last = Dissi
        
        do mm= 1,5 
             Rsi(mm,:) = Rsi(mm,:) + 3.0/2/dt_r*vol*W(mm,:) - Q(mm,:)
            !W(mm,:) = W0(mm,:) - alpha(m)*dt/vol * 1.0/(1.0 + 3.0/2/dt_r*alpha(m)*dt )  * ( Rsi(mm,:)- Q(mm,:) ) 
             W(mm,:) = W0(mm,:) - alpha(m)*dt/vol  *  Rsi(mm,:)
        end do
      
        !calculate the original variables
        U(1,:) = W(1,:)
        U(2,:) = W(2,:)/W(1,:)
        U(3,:) = W(3,:)/W(1,:)
        U(5,:) = (gamma-1.0)*( W(5,:)-U(1,:)*( U(2,:)**2 + U(3,:)**2) / 2.0 )  
      
    end do 
    
    
end subroutine

subroutine Converge(flag)          !verify wheather the flow converge
    implicit none
    integer::i,j
    integer::flag                  !flag, 1:converge;0:disconverge
    real(8)::rou_ncell=0.0    !the mean density of n+1 layer
    real(8)::u_ncell=0.0    !the mean density of n+1 layer
    real(8)::v_ncell=0.0    !the mean density of n+1 layer
    real(8)::p_ncell=0.0    !the mean density of n+1 layer
      
    real(8),save::rou_mean = 1.225  !the mean density of n layer
    real(8),save::u_mean = 0.0  !the mean density of n layer
    real(8),save::v_mean = 0.0  !the mean density of n laye
    real(8),save::p_mean = 103150.0  !the mean density of n layer


    !write(*,*)  "Converge"

    rou_ncell = sum(U(1,:))/ncells
    u_ncell = sum(U(2,:))/ncells
    v_ncell = sum(U(3,:))/ncells
    p_ncell = sum(U(5,:))/ncells
    
    flag = 0
    
    if (abs(rou_ncell-rou_mean) .LE. eps)   flag = 1
    write(*,*)  muT(1)
    write(*,*)  U(1,1),U(2,1),U(3,1),U(5,1)
    write(*,*)  abs(rou_ncell-rou_mean),abs(p_ncell-p_mean)
    write(*,*)  abs(u_ncell-u_mean),abs(v_ncell-v_mean)
    write(*,*)
       
    rou_mean = rou_ncell
    u_mean = u_ncell
    v_mean = v_ncell
    p_mean = p_ncell
    
end subroutine

end module
    