!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     This file converts a POP grid.dat file to a remapping grid file
!     in netCDF format.
!
!-----------------------------------------------------------------------
!
!     CVS:$Id: convertPOPT.f,v 1.4 2001/08/21 21:22:56 pwjones Exp $
!
!     Copyright (c) 1997, 1998 the Regents of the University of 
!       California.
!
!     Unless otherwise indicated, this software has been authored
!     by an employee or employees of the University of California,
!     operator of the Los Alamos National Laboratory under Contract
!     No. W-7405-ENG-36 with the U.S. Department of Energy.  The U.S.
!     Government has rights to use, reproduce, and distribute this
!     software.  The public may copy and use this software without
!     charge, provided that this Notice and any statement of authorship
!     are reproduced on all copies.  Neither the Government nor the
!     University makes any warranty, express or implied, or assumes
!     any liability or responsibility for the use of this software.
!
!***********************************************************************

      program myconvertPOPT

!-----------------------------------------------------------------------
!
!     This file converts a POP grid.dat file to a remapping grid file.
!
!-----------------------------------------------------------------------

      use kinds_mod
      use constants
      use iounits
      use netcdf_mod

      implicit none

!-----------------------------------------------------------------------
!
!     variables that describe the grid
!       4/3       nx = 192, ny = 128
!       2/3 (mod) nx = 384, ny = 288
!       x3p Greenland DP nx = 100, ny = 116
!       x2p Greenland DP nx = 160, ny = 192
!       x1p Greenland DP nx = 320, ny = 384
!
!-----------------------------------------------------------------------

      integer (kind=int_kind), parameter ::
     &             grid_rank = 2,
     &             grid_corners = 4

      integer (kind=int_kind) ::
     &             nx, ny, grid_size

      integer (kind=int_kind), dimension(2) ::
     &             grid_dims   ! size of each dimension

      character(char_len):: 
     &    grid_name,grid_file_in,grid_topo_in,
     &    grid_file_out

      real (kind=dbl_kind), parameter ::
     &  radius    = 6371.22e5_dbl_kind       ! radius of Earth (cm)
     &, area_norm = one/(radius*radius)

!-----------------------------------------------------------------------
!
!     grid coordinates and masks
!
!-----------------------------------------------------------------------

      integer (kind=int_kind), allocatable ::
     &             grid_imask(:)

      real (kind=dbl_kind), allocatable ::
     &             grid_area(:)      ,  ! area as computed in POP
     &             grid_center_lat(:),  ! lat/lon coordinates for
     &             grid_center_lon(:)   ! each grid center in radians

      real (kind=dbl_kind), allocatable ::
     &             grid_corner_lat(:,:),  ! lat/lon coordinates for
     &             grid_corner_lon(:,:)   ! each grid corner in radians

      real (kind=dbl_kind), allocatable ::
     &             HTN(:,:), HTE(:,:)     ! T-cell grid lengths

!-----------------------------------------------------------------------
!
!     other local variables
!
!-----------------------------------------------------------------------

      integer (kind=int_kind) :: i, j, n, iunit, ocn_add, im1, jm1
      integer (kind=int_kind) :: jp1, jp2
      real (kind=dbl_kind) ::  z1,x1,y1,z2,x2,y2,z3,x3,y3
      real (kind=dbl_kind) ::  z4,x4,y4,tx,ty,tz,da

      integer (kind=int_kind) ::
     &        ncstat,            ! general netCDF status variable
     &        nc_grid_id,        ! netCDF grid dataset id
     &        nc_gridsize_id,    ! netCDF grid size dim id
     &        nc_gridcorn_id,    ! netCDF grid corner dim id
     &        nc_gridrank_id,    ! netCDF grid rank dim id
     &        nc_griddims_id,    ! netCDF grid dimensions id
     &        nc_grdcntrlat_id,  ! netCDF grid center lat id
     &        nc_grdcntrlon_id,  ! netCDF grid center lon id
     &        nc_grdimask_id,    ! netCDF grid mask id
     &        nc_gridarea_id,    ! netCDF grid area id
     &        nc_grdcrnrlat_id,  ! netCDF grid corner lat id
     &        nc_grdcrnrlon_id   ! netCDF grid corner lon id

      integer (kind=int_kind), dimension(2) ::
     &        nc_dims2_id        ! netCDF dim id array for 2-d arrays

      real (kind=dbl_kind) :: tmplon, dxt, dyt, dlat

      integer :: reclen
!-----------------------------------------------------------------------
!
!     read in grid info
!     lat/lon info is on velocity points which correspond
!     to the NE corner (in logical space) of the grid cell.
!
!-----------------------------------------------------------------------
      print *, "enter grid nx, ny"
      read(*,*) nx, ny

      grid_size = nx*ny

      print *, "enter grid_name:"
      read(*,'(a120)') grid_name
      print *, "enter grid_file_in:"
      read(*,'(a120)') grid_file_in
      print *, "enter grid_topo_in:"
      read(*,'(a120)') grid_topo_in
      print *, "enter grid_file_out:"
      read(*,'(a120)') grid_file_out

      allocate(grid_imask(grid_size))
      allocate(grid_area(grid_size))
      allocate(grid_center_lat(grid_size))
      allocate(grid_center_lon(grid_size))
      allocate(grid_corner_lat(grid_corners,grid_size))
      allocate(grid_corner_lon(grid_corners,grid_size))
      allocate(HTN(nx,ny))
      allocate(HTE(nx,ny))

      call get_unit(iunit)
      inquire(iolength=reclen) grid_imask
      open(unit=iunit, file=grid_topo_in, status='old', 
     &     form='unformatted', access='direct', recl=reclen)
      read (unit=iunit,rec=1) grid_imask
      call release_unit(iunit)

      call get_unit(iunit)
      inquire(iolength=reclen) grid_corner_lat(3,:)
      open(unit=iunit, file=grid_file_in, status='old', 
     &     form='unformatted', access='direct', recl=reclen)
      read (unit=iunit, rec=1) grid_corner_lat(3,:)
      read (unit=iunit, rec=2) grid_corner_lon(3,:)
      read (unit=iunit, rec=3) HTN
      read (unit=iunit, rec=4) HTE
      call release_unit(iunit)

      grid_dims(1) = nx
      grid_dims(2) = ny

!-----------------------------------------------------------------------
!
!     convert KMT field to integer grid mask
!
!-----------------------------------------------------------------------

      grid_imask = min(grid_imask, 1)

!-----------------------------------------------------------------------
!
!     compute remaining corners
!
!-----------------------------------------------------------------------

      do j=1,ny
        do i=1,nx
          ocn_add = (j-1)*nx + i
          if (i .ne. 1) then
            im1 = ocn_add - 1
          else
            im1 = ocn_add + nx - 1
          endif

          grid_corner_lat(4,ocn_add) = grid_corner_lat(3,im1)
          grid_corner_lon(4,ocn_add) = grid_corner_lon(3,im1)
        end do
      end do

      do j=2,ny
        do i=1,nx
          ocn_add = (j-1)*nx + i
          jm1 = (j-2)*nx + i

          grid_corner_lat(2,ocn_add) = grid_corner_lat(3,jm1)
          grid_corner_lat(1,ocn_add) = grid_corner_lat(4,jm1)

          grid_corner_lon(2,ocn_add) = grid_corner_lon(3,jm1)
          grid_corner_lon(1,ocn_add) = grid_corner_lon(4,jm1)
        end do
      end do

!-----------------------------------------------------------------------
!
!     mock up the lower row boundaries
!
!-----------------------------------------------------------------------

      do i=1,nx
        dlat = grid_corner_lat(1,i+2*nx) - grid_corner_lat(1,i+nx)
        grid_corner_lat(1,i) = grid_corner_lat(1,i+nx) - dlat
        grid_corner_lat(1,i) = max(grid_corner_lat(1,i), -pih + tiny)

        dlat = grid_corner_lat(2,i+2*nx) - grid_corner_lat(2,i+nx)
        grid_corner_lat(2,i) = grid_corner_lat(2,i+nx) - dlat
        grid_corner_lat(2,i) = max(grid_corner_lat(2,i), -pih + tiny)

        grid_corner_lon(1,i) = grid_corner_lon(4,i)
        grid_corner_lon(2,i) = grid_corner_lon(3,i)
      end do

!-----------------------------------------------------------------------
!
!     correct for 0,2pi longitude crossings
!
!-----------------------------------------------------------------------

      do ocn_add=1,grid_size
        if (grid_corner_lon(1,ocn_add) > pi2) 
     &      grid_corner_lon(1,ocn_add) = 
     &      grid_corner_lon(1,ocn_add) - pi2
        if (grid_corner_lon(1,ocn_add) < 0.0) 
     &      grid_corner_lon(1,ocn_add) = 
     &      grid_corner_lon(1,ocn_add) + pi2
        do n=2,grid_corners
          tmplon = grid_corner_lon(n  ,ocn_add) - 
     &             grid_corner_lon(n-1,ocn_add) 
          if (tmplon < -three*pih) grid_corner_lon(n,ocn_add) = 
     &                             grid_corner_lon(n,ocn_add) + pi2
          if (tmplon >  three*pih) grid_corner_lon(n,ocn_add) = 
     &                             grid_corner_lon(n,ocn_add) - pi2
        end do
      end do

!-----------------------------------------------------------------------
!
!     compute ocean cell centers by averaging corner values
!
!-----------------------------------------------------------------------

!     start calc_tpoints stuff

      do j=2,ny
        do i=1,nx
	    ocn_add = (j-1)*nx + i

            z1 = cos(grid_corner_lat(1,ocn_add))
            x1 = cos(grid_corner_lon(1,ocn_add))*z1
            y1 = sin(grid_corner_lon(1,ocn_add))*z1
            z1 = sin(grid_corner_lat(1,ocn_add))

            z2 = cos(grid_corner_lat(2,ocn_add))
            x2 = cos(grid_corner_lon(2,ocn_add))*z2
            y2 = sin(grid_corner_lon(2,ocn_add))*z2
            z2 = sin(grid_corner_lat(2,ocn_add))

            z3 = cos(grid_corner_lat(4,ocn_add))
            x3 = cos(grid_corner_lon(4,ocn_add))*z3
            y3 = sin(grid_corner_lon(4,ocn_add))*z3
            z3 = sin(grid_corner_lat(4,ocn_add))

            z4 = cos(grid_corner_lat(3,ocn_add))
            x4 = cos(grid_corner_lon(3,ocn_add))*z4
            y4 = sin(grid_corner_lon(3,ocn_add))*z4
            z4 = sin(grid_corner_lat(3,ocn_add))

            tx = (x1+x2+x3+x4)/four
            ty = (y1+y2+y3+y4)/four
            tz = (z1+z2+z3+z4)/four
            da = sqrt(tx**2+ty**2+tz**2)

            tz = tz/da
            ! TLONG_G in radians
            grid_center_lon(ocn_add) = zero
            if (tx.ne.zero.or.ty.ne.zero)
     &           grid_center_lon(ocn_add) = atan2(ty,tx)
            ! TLAT_G in radians
            grid_center_lat(ocn_add) = asin(tz)

        end do
      end do

      ! j=1: linear approximation
      do i=1,nx
	 ocn_add = i
	 jp1 = nx + i
	 jp2 = 2*nx + i
         grid_center_lon(ocn_add) = grid_center_lon(jp1)
         grid_center_lat(ocn_add) = two*grid_center_lat(jp1) - 
     &		grid_center_lat(jp2)
      end do

!     end calc_tpoints stuff

      do ocn_add=1,grid_size
        if (grid_center_lon(ocn_add) > pi2) 
     &      grid_center_lon(ocn_add) = grid_center_lon(ocn_add) - pi2
        if (grid_center_lon(ocn_add) < 0.0) 
     &      grid_center_lon(ocn_add) = grid_center_lon(ocn_add) + pi2
      end do

!-----------------------------------------------------------------------
!
!     compute cell areas in same way as POP
!
!-----------------------------------------------------------------------

      n = 0
      do j=1,ny
        if (j > 1) then
          jm1 = j-1
        else
          jm1 = 1
        endif
        do i=1,nx
          if (i > 1) then
            im1 = i-1
          else
            im1 = nx
          endif

          n = n+1

          dxt = half*(HTN(i,j) + HTN(i,jm1))
          dyt = half*(HTE(i,j) + HTE(im1,j))
          if (dxt == zero) dxt=one
          if (dyt == zero) dyt=one

          grid_area(n) = dxt*dyt*area_norm
        end do
      end do

!-----------------------------------------------------------------------
!
!     set up attributes for netCDF file
!
!-----------------------------------------------------------------------

      !***
      !*** create netCDF dataset for this grid
      !***

      ncstat = nf_create (grid_file_out, NF_CLOBBER,
     &                    nc_grid_id)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_att_text (nc_grid_id, NF_GLOBAL, 'title',
     &                          len_trim(grid_name), grid_name)
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid size dimension
      !***

      ncstat = nf_def_dim (nc_grid_id, 'grid_size', grid_size, 
     &                     nc_gridsize_id)
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid rank dimension
      !***

      ncstat = nf_def_dim (nc_grid_id, 'grid_rank', grid_rank, 
     &                     nc_gridrank_id)
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid corner dimension
      !***

      ncstat = nf_def_dim (nc_grid_id, 'grid_corners', grid_corners, 
     &                     nc_gridcorn_id)
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid dim size array
      !***

      ncstat = nf_def_var (nc_grid_id, 'grid_dims', NF_INT,
     &                     1, nc_gridrank_id, nc_griddims_id)
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid center latitude array
      !***

      ncstat = nf_def_var (nc_grid_id, 'grid_center_lat', NF_DOUBLE,
     &                     1, nc_gridsize_id, nc_grdcntrlat_id)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_att_text (nc_grid_id, nc_grdcntrlat_id, 'units',
     &                          7, 'radians')
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid center longitude array
      !***

      ncstat = nf_def_var (nc_grid_id, 'grid_center_lon', NF_DOUBLE,
     &                     1, nc_gridsize_id, nc_grdcntrlon_id)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_att_text (nc_grid_id, nc_grdcntrlon_id, 'units',
     &                          7, 'radians')
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid area array
      !***

      ncstat = nf_def_var (nc_grid_id, 'grid_area', NF_DOUBLE,
     &                     1, nc_gridsize_id, nc_gridarea_id)
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid mask
      !***

      ncstat = nf_def_var (nc_grid_id, 'grid_imask', NF_INT,
     &                     1, nc_gridsize_id, nc_grdimask_id)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_att_text (nc_grid_id, nc_grdimask_id, 'units',
     &                          8, 'unitless')
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid corner latitude array
      !***

      nc_dims2_id(1) = nc_gridcorn_id
      nc_dims2_id(2) = nc_gridsize_id

      ncstat = nf_def_var (nc_grid_id, 'grid_corner_lat', NF_DOUBLE,
     &                     2, nc_dims2_id, nc_grdcrnrlat_id)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_att_text (nc_grid_id, nc_grdcrnrlat_id, 'units',
     &                          7, 'radians')
      call netcdf_error_handler(ncstat)

      !***
      !*** define grid corner longitude array
      !***

      ncstat = nf_def_var (nc_grid_id, 'grid_corner_lon', NF_DOUBLE,
     &                     2, nc_dims2_id, nc_grdcrnrlon_id)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_att_text (nc_grid_id, nc_grdcrnrlon_id, 'units',
     &                          7, 'radians')
      call netcdf_error_handler(ncstat)

      !***
      !*** end definition stage
      !***

      ncstat = nf_enddef(nc_grid_id)
      call netcdf_error_handler(ncstat)

!-----------------------------------------------------------------------
!
!     write grid data
!
!-----------------------------------------------------------------------

      ncstat = nf_put_var_int(nc_grid_id, nc_griddims_id, grid_dims)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_var_double(nc_grid_id, nc_grdcntrlat_id, 
     &                           grid_center_lat)
      ncstat = nf_put_var_int(nc_grid_id, nc_grdimask_id, grid_imask)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_var_double(nc_grid_id, nc_gridarea_id, 
     &                           grid_area)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_var_double(nc_grid_id, nc_grdcntrlat_id, 
     &                           grid_center_lat)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_var_double(nc_grid_id, nc_grdcntrlon_id, 
     &                           grid_center_lon)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_var_double(nc_grid_id, nc_grdcrnrlat_id, 
     &                           grid_corner_lat)
      call netcdf_error_handler(ncstat)

      ncstat = nf_put_var_double(nc_grid_id, nc_grdcrnrlon_id, 
     &                           grid_corner_lon)
      call netcdf_error_handler(ncstat)

      ncstat = nf_close(nc_grid_id)

!***********************************************************************

      end program myconvertPOPT

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
