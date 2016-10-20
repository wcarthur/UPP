!
! Example1_Simple
!
! Example1: Program to provide a (relatively) simple example of how
!           to call the CRTM K-Matrix function.
!
!
! CREATION HISTORY:
!       Written by:     Paul van Delst, 01-Feb-2008
!                       paul.vandelst@noaa.gov
!

PROGRAM Example1_Simple

  ! ============================================================================
  ! **** ENVIRONMENT SETUP FOR RTM USAGE ****
  !
  ! Module usage
  USE CRTM_Module
  ! Disable all implicit typing
  IMPLICIT NONE
  ! ============================================================================


  ! ----------
  ! Parameters
  ! ----------
  CHARACTER(*), PARAMETER :: PROGRAM_NAME   = 'Example1_Simple'
  CHARACTER(*), PARAMETER :: PROGRAM_VERSION_ID = &
    '$Id: Example1_Simple.f90 22707 2012-11-21 21:09:10Z paul.vandelst@noaa.gov $'
  CHARACTER(*), PARAMETER :: RESULTS_PATH = './results/'


  ! ============================================================================
  ! 0. **** SOME SET UP PARAMETERS FOR THIS EXAMPLE ****
  !
  ! This example processes TWO profiles of 100 layers and
  !                                          2 absorbers and
  !                                          1 clouds and
  !                                          1 aerosols....
  INTEGER, PARAMETER :: N_PROFILES  = 2
  INTEGER, PARAMETER :: N_LAYERS    = 92
  INTEGER, PARAMETER :: N_ABSORBERS = 2
  INTEGER, PARAMETER :: N_CLOUDS    = 1
  INTEGER, PARAMETER :: N_AEROSOLS  = 1
  ! ...but only ONE Sensor at a time
  INTEGER, PARAMETER :: N_SENSORS = 1

  ! Test GeometryInfo angles. The test scan angle is based
  ! on the default Re (earth radius) and h (satellite height)                                                      
  REAL(fp), PARAMETER :: ZENITH_ANGLE = 30.0_fp
  REAL(fp), PARAMETER :: SCAN_ANGLE   = 26.37293341421_fp
  ! ============================================================================
  
  
  ! ---------
  ! Variables
  ! ---------
  CHARACTER(256) :: Message
  CHARACTER(256) :: Version
  CHARACTER(256) :: Sensor_Id
  INTEGER :: Error_Status
  INTEGER :: Allocate_Status
  INTEGER :: n_Channels
  INTEGER :: k1, k2, l, m
  ! Declarations for Jacobian comparisons
  INTEGER :: n_la, n_ma
  INTEGER :: n_ls, n_ms
  CHARACTER(256) :: atmk_File, sfck_File
  TYPE(CRTM_Atmosphere_type), ALLOCATABLE :: atm_k(:,:)
  TYPE(CRTM_Surface_type)   , ALLOCATABLE :: sfc_k(:,:)



  ! ============================================================================
  ! 1. **** DEFINE THE CRTM INTERFACE STRUCTURES ****
  !
  TYPE(CRTM_ChannelInfo_type)             :: ChannelInfo(N_SENSORS)
  TYPE(CRTM_Geometry_type)                :: Geometry(N_PROFILES)

  ! Define the FORWARD variables
  TYPE(CRTM_Atmosphere_type)              :: Atmosphere(N_PROFILES)
  TYPE(CRTM_Surface_type)                 :: Surface(N_PROFILES)
  TYPE(CRTM_RTSolution_type), ALLOCATABLE :: RTSolution(:,:)

  ! Define the K-MATRIX variables
  TYPE(CRTM_Atmosphere_type), ALLOCATABLE :: Atmosphere_K(:,:)
  TYPE(CRTM_Surface_type)   , ALLOCATABLE :: Surface_K(:,:)
  TYPE(CRTM_RTSolution_type), ALLOCATABLE :: RTSolution_K(:,:)
  ! ============================================================================



  ! Program header
  ! --------------
  CALL CRTM_Version( Version )
  CALL Program_Message( PROGRAM_NAME, &
                        'Program to provide a (relatively) simple example of how '//&
                        'to call the CRTM K-Matrix function.', &
                        'CRTM Version: '//TRIM(Version) )


  ! Get sensor id from user
  ! -----------------------
  WRITE( *,'(/5x,"Enter sensor id [hirs4_n18, amsua_metop-a, or mhs_n18]: ")',ADVANCE='NO' )
  READ( *,'(a)' ) Sensor_Id
  Sensor_Id = ADJUSTL(Sensor_Id)
  WRITE( *,'(//5x,"Running CRTM for ",a," sensor...")' ) TRIM(Sensor_Id)
  

  ! ============================================================================
  ! 2. **** INITIALIZE THE CRTM ****
  !
  ! 2a. This initializes the CRTM for the sensors 
  !     predefined in the example SENSOR_ID parameter.
  !     NOTE: The coefficient data file path is hard-
  !           wired for this example.
  ! --------------------------------------------------
  WRITE( *,'(/5x,"Initializing the CRTM...")' )
  Error_Status = CRTM_Init( (/Sensor_Id/), &  ! Input... must be an array, hence the (/../)
                            ChannelInfo  , &  ! Output
                            EmisCoeff_File='Nalli.EK-PDF.W_W-RefInd.EmisCoeff.bin', &
                            File_Path='coefficients/' )
  IF ( Error_Status /= SUCCESS ) THEN 
    Message = 'Error initializing CRTM' 
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF

  ! 2b. Determine the total number of channels
  !     for which the CRTM was initialized
  ! ------------------------------------------
  n_Channels = SUM(ChannelInfo%n_Channels)
  ! ============================================================================




  ! ============================================================================
  ! 3. **** ALLOCATE STRUCTURE ARRAYS ****
  !
  ! 3a. Allocate the ARRAYS
  ! -----------------------
  ! Note that only those structure arrays with a channel
  ! dimension are allocated here because we've parameterized
  ! the number of profiles in the N_PROFILES parameter.
  !
  ! Users can make the number of profiles dynamic also, but
  ! then the INPUT arrays (Atmosphere, Surface) will also have to be allocated.
  ALLOCATE( RTSolution( n_Channels, N_PROFILES ), &
            Atmosphere_K( n_Channels, N_PROFILES ), &
            Surface_K( n_Channels, N_PROFILES ), &
            RTSolution_K( n_Channels, N_PROFILES ), &
            STAT = Allocate_Status )
  IF ( Allocate_Status /= 0 ) THEN 
    Message = 'Error allocating structure arrays' 
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF

  ! 3b. Allocate the STRUCTURES
  ! ---------------------------
  ! The input FORWARD structure
  CALL CRTM_Atmosphere_Create( Atmosphere, N_LAYERS, N_ABSORBERS, N_CLOUDS, N_AEROSOLS )
  IF ( ANY(.NOT. CRTM_Atmosphere_Associated(Atmosphere)) ) THEN
    Message = 'Error allocating CRTM Atmosphere structure'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF

  ! The output K-MATRIX structure
  CALL CRTM_Atmosphere_Create( Atmosphere_K, N_LAYERS, N_ABSORBERS, N_CLOUDS, N_AEROSOLS )
  IF ( ANY(.NOT. CRTM_Atmosphere_Associated(Atmosphere_K)) ) THEN
    Message = 'Error allocating CRTM Atmosphere_K structure'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF
  ! ============================================================================




  ! ============================================================================
  ! 4. **** ASSIGN INPUT DATA ****
  !
  ! Fill the Atmosphere structure array. 
  ! NOTE: This is an example program for illustrative purposes only.
  !       Typically, one would not assign the data as shown below,
  !       but rather read it from file
  
  ! 4a. Atmosphere and Surface input
  ! --------------------------------
  CALL Load_AtmSfc_Data()


  ! 4b. GeometryInfo input
  ! ----------------------
  ! All profiles are given the same value
  !  The Sensor_Scan_Angle is optional.
  CALL CRTM_Geometry_SetValue( Geometry, &
                               Sensor_Zenith_Angle = ZENITH_ANGLE, &
                               Sensor_Scan_Angle   = SCAN_ANGLE )


  ! ============================================================================




  ! ============================================================================
  ! 5. **** INITIALIZE THE K-MATRIX ARGUMENTS ****
  !
  ! 5a. Zero the K-matrix OUTPUT structures
  ! ---------------------------------------
  CALL CRTM_Atmosphere_Zero( Atmosphere_K )
  CALL CRTM_Surface_Zero( Surface_K )

  ! 5b. Inintialize the K-matrix INPUT so
  !     that all the results are dTb/dx
  ! -------------------------------------
  RTSolution_K%Brightness_Temperature = ONE
  ! ============================================================================




  ! ============================================================================
  ! 6. **** CALL THE CRTM K-MATRIX MODEL ****
  !
  Error_Status = CRTM_K_Matrix( Atmosphere  , &  
                                Surface     , &  
                                RTSolution_K, &  
                                Geometry    , &  
                                ChannelInfo , &  
                                Atmosphere_K, &  
                                Surface_K   , &  
                                RTSolution  )
  IF ( Error_Status /= SUCCESS ) THEN 
    Message = 'Error in CRTM K_Matrix Model'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF
  ! ============================================================================




  ! ============================================================================
  ! 7. **** OUTPUT THE RESULTS TO SCREEN ****
  !
  ! (a) User should read the user guide or the source codes of the routines
  !     CRTM_RTSolution_Inspect in the file CRTM_RTSolution_Define.f90, 
  !     CRTM_Surface_Inspect in the file CRTM_Surface_Inspect, and CRTM_Atmosphere_Inspect
  !     in the file CRTM_Atmosphere_Define.f90 to select the needed variables for outputs.
  ! (b) The Forward results are contained in the structure RTSolution
  ! (c) The Jacobians for the atmospheric variables are contained in the structure Atmosphere_K
  ! (d) The Jacobians for the Surface related variables are contained in the structure Surface_K
  DO m = 1, N_PROFILES
    WRITE( *,'(//7x,"Profile ",i0," output for ",a )') m, TRIM(Sensor_Id)
    DO l = 1, n_Channels
      WRITE( *, '(/5x,"Channel ",i0," results")') ChannelInfo(1)%Sensor_Channel(l)
      ! FWD output
      WRITE( *, '(/3x,"FORWARD OUTPUT")')
      CALL CRTM_RTSolution_Inspect(RTSolution(l,m))
      ! K-MATRIX output
      WRITE( *, '(/3x,"K-MATRIX OUTPUT")')
      CALL CRTM_Surface_Inspect(Surface_K(l,m))
      CALL CRTM_Atmosphere_Inspect(Atmosphere_K(l,m))
    END DO
  END DO
  ! ============================================================================
  


  
  ! ============================================================================
  ! 8. **** DESTROY THE CRTM ****
  !
  WRITE( *, '( /5x, "Destroying the CRTM..." )' )
  Error_Status = CRTM_Destroy( ChannelInfo )
  IF ( Error_Status /= SUCCESS ) THEN 
    Message = 'Error destroying CRTM'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )
    STOP
  END IF
  ! ============================================================================




  ! ============================================================================
  ! 9. **** COMPARE Atmosphere_K and Surface_K RESULTS TO SAVED VALUES ****
  !
  !   Step 9 is not part of the example to show how to use CRTM.        
  !   It is to check the user results against the results in the CRTM package. 

  WRITE( *, '( /5x, "Comparing calculated results with saved ones..." )' )

  ! 9a. Create the output files if they do not exist
  ! ------------------------------------------------
  ! 9a.1 Atmosphere file
  ! ...Generate filename
  atmk_File = RESULTS_PATH//TRIM(Sensor_Id)//'.Atmosphere.bin'
  ! ...Check if the file exists
  IF ( .NOT. File_Exists(atmk_File) ) THEN
    Message = 'Atmosphere_K save file does not exist. Creating...'
    CALL Display_Message( PROGRAM_NAME, Message, INFORMATION )  
    ! ...File not found, so write Atmosphere_K structure to file
    Error_Status = CRTM_Atmosphere_WriteFile( atmk_file, Atmosphere_K, Quiet=.TRUE. )
    IF ( Error_Status /= SUCCESS ) THEN
      Message = 'Error creating Atmosphere_K save file'
      CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
      STOP
    END IF  
  END IF  
  ! 9a.2 Surface file
  ! ...Generate filename
  sfck_File = RESULTS_PATH//TRIM(Sensor_Id)//'.Surface.bin'
  ! ...Check if the file exists
  IF ( .NOT. File_Exists(sfck_File) ) THEN
    Message = 'Surface_K save file does not exist. Creating...'
    CALL Display_Message( PROGRAM_NAME, Message, INFORMATION )  
    ! ...File not found, so write Surface_K structure to file
    Error_Status = CRTM_Surface_WriteFile( sfck_file, Surface_K, Quiet=.TRUE. )
    IF ( Error_Status /= SUCCESS ) THEN
      Message = 'Error creating Surface_K save file'
      CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
      STOP
    END IF  
  END IF  

  ! 9b. Inquire the saved files
  ! ---------------------------
  ! 9b.1 Atmosphere file
  Error_Status = CRTM_Atmosphere_InquireFile( atmk_File, &
                                              n_Channels = n_la, &
                                              n_Profiles = n_ma )
  IF ( Error_Status /= SUCCESS ) THEN
    Message = 'Error inquiring Atmosphere_K save file'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF
  ! 9b.2 Surface file
  Error_Status = CRTM_Surface_InquireFile( sfck_File, &
                                           n_Channels = n_ls, &
                                           n_Profiles = n_ms )
  IF ( Error_Status /= SUCCESS ) THEN
    Message = 'Error inquiring Surface_K save file'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF

  ! 9c. Compare the dimensions
  ! --------------------------
  IF ( n_la /= n_Channels .OR. n_ma /= N_PROFILES .OR. &
       n_ls /= n_Channels .OR. n_ms /= N_PROFILES      ) THEN
    Message = 'Dimensions of saved data different from that calculated!'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF

  ! 9d. Allocate the structures to read in saved data
  ! -------------------------------------------------
  ALLOCATE( atm_k( n_la, n_ma ),  sfc_k( n_ls, n_ms ), STAT=Allocate_Status )
  IF ( Allocate_Status /= 0 ) THEN
    Message = 'Error allocating Atmosphere_K and Surface_K saved data arrays'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF

  ! 9e. Read the saved data
  ! -----------------------
  ! 9e.1 Atmosphere file
  Error_Status = CRTM_Atmosphere_ReadFile( atmk_File, atm_k, Quiet=.TRUE. )
  IF ( Error_Status /= SUCCESS ) THEN
    Message = 'Error reading Atmosphere_K save file'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF
  ! 9e.2 Surface file
  Error_Status = CRTM_Surface_ReadFile( sfck_File, sfc_k, Quiet=.TRUE. )
  IF ( Error_Status /= SUCCESS ) THEN
    Message = 'Error reading Surface_K save file'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    STOP
  END IF
  
  ! 9f. Compare some Jacobians
  ! --------------------------
  ! 9f.1 Atmosphere
  IF ( ALL(CRTM_Atmosphere_Compare(Atmosphere_K, atm_k, n_SigFig=3)) ) THEN
    Message = 'Atmosphere_K Jacobians are the same!'
    CALL Display_Message( PROGRAM_NAME, Message, INFORMATION )
  ELSE
    Message = 'Atmosphere_K Jacobians are different!'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )
    ! Write the current Atmosphere_K results to file
    atmk_File = TRIM(Sensor_Id)//'.Atmosphere.bin'
    Error_Status = CRTM_Atmosphere_WriteFile( atmk_file, Atmosphere_K, Quiet=.TRUE. )
    IF ( Error_Status /= SUCCESS ) THEN
      Message = 'Error creating temporary Atmosphere_K save file for failed comparison'
      CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    END IF
    STOP
  END IF
  ! 9f.2 Surface
  IF ( ALL(CRTM_Surface_Compare(Surface_K, sfc_k, n_SigFig=5)) ) THEN
    Message = 'Surface_K Jacobians are the same!'
    CALL Display_Message( PROGRAM_NAME, Message, INFORMATION )
  ELSE
    Message = 'Surface_K Jacobians are different!'
    CALL Display_Message( PROGRAM_NAME, Message, FAILURE )
    ! Write the current Surface_K results to file
    sfck_File = TRIM(Sensor_Id)//'.Surface.bin'
    Error_Status = CRTM_Surface_WriteFile( sfck_file, Surface_K, Quiet=.TRUE. )
    IF ( Error_Status /= SUCCESS ) THEN
      Message = 'Error creating temporary Surface_K save file for failed comparison'
      CALL Display_Message( PROGRAM_NAME, Message, FAILURE )  
    END IF
    STOP
  END IF
  ! ============================================================================




  ! ============================================================================
  ! 10. **** CLEAN UP ****
  !
  ! 10a. Deallocate the structures.
  !      These are the explicitly allocated structures.
  !      Note that in some cases other structures, such as the Sfc
  !      and RTSolution structures, will also be allocated and thus
  !      should also be deallocated here.
  ! ---------------------------------------------------------------
  CALL CRTM_Atmosphere_Destroy(Atmosphere_K)
  CALL CRTM_Atmosphere_Destroy(Atmosphere)

  ! 10b. Deallocate the arrays
  ! --------------------------
  DEALLOCATE(RTSolution, RTSolution_K, &
             Surface_K, Atmosphere_K, &
             STAT = Allocate_Status)
  ! ============================================================================

  ! Signal the completion of the program. It is not a necessary step for running CRTM.
  CALL SignalFile_Create()

CONTAINS


  ! -------------------------------------------------
  ! Internal subprogam to load some test profile data
  ! -------------------------------------------------
  SUBROUTINE Load_AtmSfc_Data()
  
    ! 4a.1 Profile #1
    ! ---------------
    Surface(1)%Land_Coverage    = 1.0_fp
    Surface(1)%Land_Type        = SCRUB
    Surface(1)%Land_Temperature = 318.0_fp
  
    Atmosphere(1)%Climatology    = TROPICAL
    Atmosphere(1)%Absorber_Id    = (/ H2O_ID                 , O3_ID /)
    Atmosphere(1)%Absorber_Units = (/ MASS_MIXING_RATIO_UNITS, VOLUME_MIXING_RATIO_UNITS /)

    Atmosphere(1)%Level_Pressure = &
    (/0.004_fp,   0.975_fp,   1.297_fp,   1.687_fp,   2.153_fp,   2.701_fp,   3.340_fp,   4.077_fp, &
      4.920_fp,   5.878_fp,   6.957_fp,   8.165_fp,   9.512_fp,  11.004_fp,  12.649_fp,  14.456_fp, &
     16.432_fp,  18.585_fp,  20.922_fp,  23.453_fp,  26.183_fp,  29.121_fp,  32.274_fp,  35.650_fp, &
     39.257_fp,  43.100_fp,  47.188_fp,  51.528_fp,  56.126_fp,  60.990_fp,  66.125_fp,  71.540_fp, &
     77.240_fp,  83.231_fp,  89.520_fp,  96.114_fp, 103.017_fp, 110.237_fp, 117.777_fp, 125.646_fp, &
    133.846_fp, 142.385_fp, 151.266_fp, 160.496_fp, 170.078_fp, 180.018_fp, 190.320_fp, 200.989_fp, &
    212.028_fp, 223.441_fp, 235.234_fp, 247.409_fp, 259.969_fp, 272.919_fp, 286.262_fp, 300.000_fp, &
    314.137_fp, 328.675_fp, 343.618_fp, 358.967_fp, 374.724_fp, 390.893_fp, 407.474_fp, 424.470_fp, &
    441.882_fp, 459.712_fp, 477.961_fp, 496.630_fp, 515.720_fp, 535.232_fp, 555.167_fp, 575.525_fp, &
    596.306_fp, 617.511_fp, 639.140_fp, 661.192_fp, 683.667_fp, 706.565_fp, 729.886_fp, 753.627_fp, &
    777.790_fp, 802.371_fp, 827.371_fp, 852.788_fp, 878.620_fp, 904.866_fp, 931.524_fp, 958.591_fp, &
    986.067_fp,1013.948_fp,1042.232_fp,1070.917_fp,1100.000_fp/)
  
    Atmosphere(1)%Pressure = &
    (/0.838_fp,   1.129_fp,   1.484_fp,   1.910_fp,   2.416_fp,   3.009_fp,   3.696_fp,   4.485_fp, &
      5.385_fp,   6.402_fp,   7.545_fp,   8.822_fp,  10.240_fp,  11.807_fp,  13.532_fp,  15.423_fp, &
     17.486_fp,  19.730_fp,  22.163_fp,  24.793_fp,  27.626_fp,  30.671_fp,  33.934_fp,  37.425_fp, &
     41.148_fp,  45.113_fp,  49.326_fp,  53.794_fp,  58.524_fp,  63.523_fp,  68.797_fp,  74.353_fp, &
     80.198_fp,  86.338_fp,  92.778_fp,  99.526_fp, 106.586_fp, 113.965_fp, 121.669_fp, 129.703_fp, &
    138.072_fp, 146.781_fp, 155.836_fp, 165.241_fp, 175.001_fp, 185.121_fp, 195.606_fp, 206.459_fp, &
    217.685_fp, 229.287_fp, 241.270_fp, 253.637_fp, 266.392_fp, 279.537_fp, 293.077_fp, 307.014_fp, &
    321.351_fp, 336.091_fp, 351.236_fp, 366.789_fp, 382.751_fp, 399.126_fp, 415.914_fp, 433.118_fp, &
    450.738_fp, 468.777_fp, 487.236_fp, 506.115_fp, 525.416_fp, 545.139_fp, 565.285_fp, 585.854_fp, &
    606.847_fp, 628.263_fp, 650.104_fp, 672.367_fp, 695.054_fp, 718.163_fp, 741.693_fp, 765.645_fp, &
    790.017_fp, 814.807_fp, 840.016_fp, 865.640_fp, 891.679_fp, 918.130_fp, 944.993_fp, 972.264_fp, &
    999.942_fp,1028.025_fp,1056.510_fp,1085.394_fp/)

    Atmosphere(1)%Temperature = &
    (/266.536_fp, 269.608_fp, 270.203_fp, 264.526_fp, 251.578_fp, 240.264_fp, 235.095_fp, 232.959_fp, &
      233.017_fp, 233.897_fp, 234.385_fp, 233.681_fp, 232.436_fp, 231.607_fp, 231.192_fp, 230.808_fp, &
      230.088_fp, 228.603_fp, 226.407_fp, 223.654_fp, 220.525_fp, 218.226_fp, 216.668_fp, 215.107_fp, &
      213.538_fp, 212.006_fp, 210.507_fp, 208.883_fp, 206.793_fp, 204.415_fp, 202.058_fp, 199.718_fp, &
      197.668_fp, 196.169_fp, 194.993_fp, 194.835_fp, 195.648_fp, 196.879_fp, 198.830_fp, 201.091_fp, &
      203.558_fp, 206.190_fp, 208.900_fp, 211.736_fp, 214.601_fp, 217.522_fp, 220.457_fp, 223.334_fp, &
      226.156_fp, 228.901_fp, 231.557_fp, 234.173_fp, 236.788_fp, 239.410_fp, 242.140_fp, 244.953_fp, &
      247.793_fp, 250.665_fp, 253.216_fp, 255.367_fp, 257.018_fp, 258.034_fp, 258.778_fp, 259.454_fp, &
      260.225_fp, 261.251_fp, 262.672_fp, 264.614_fp, 266.854_fp, 269.159_fp, 271.448_fp, 273.673_fp, &
      275.955_fp, 278.341_fp, 280.822_fp, 283.349_fp, 285.826_fp, 288.288_fp, 290.721_fp, 293.135_fp, &
      295.609_fp, 298.173_fp, 300.787_fp, 303.379_fp, 305.960_fp, 308.521_fp, 310.916_fp, 313.647_fp, &
      315.244_fp, 315.244_fp, 315.244_fp, 315.244_fp/)

    Atmosphere(1)%Absorber(:,1) = &
    (/3.887E-03_fp,3.593E-03_fp,3.055E-03_fp,2.856E-03_fp,2.921E-03_fp,2.555E-03_fp,2.392E-03_fp,2.605E-03_fp, &
      2.573E-03_fp,2.368E-03_fp,2.354E-03_fp,2.333E-03_fp,2.312E-03_fp,2.297E-03_fp,2.287E-03_fp,2.283E-03_fp, &
      2.282E-03_fp,2.286E-03_fp,2.296E-03_fp,2.309E-03_fp,2.324E-03_fp,2.333E-03_fp,2.335E-03_fp,2.335E-03_fp, &
      2.333E-03_fp,2.340E-03_fp,2.361E-03_fp,2.388E-03_fp,2.421E-03_fp,2.458E-03_fp,2.492E-03_fp,2.523E-03_fp, &
      2.574E-03_fp,2.670E-03_fp,2.789E-03_fp,2.944E-03_fp,3.135E-03_fp,3.329E-03_fp,3.530E-03_fp,3.759E-03_fp, &
      4.165E-03_fp,4.718E-03_fp,5.352E-03_fp,6.099E-03_fp,6.845E-03_fp,7.524E-03_fp,8.154E-03_fp,8.381E-03_fp, &
      8.214E-03_fp,8.570E-03_fp,9.672E-03_fp,1.246E-02_fp,1.880E-02_fp,2.720E-02_fp,3.583E-02_fp,4.462E-02_fp, &
      4.548E-02_fp,3.811E-02_fp,3.697E-02_fp,4.440E-02_fp,2.130E-01_fp,6.332E-01_fp,9.945E-01_fp,1.073E+00_fp, &
      1.196E+00_fp,1.674E+00_fp,2.323E+00_fp,2.950E+00_fp,3.557E+00_fp,4.148E+00_fp,4.666E+00_fp,5.092E+00_fp, &
      5.487E+00_fp,5.852E+00_fp,6.137E+00_fp,6.297E+00_fp,6.338E+00_fp,6.234E+00_fp,5.906E+00_fp,5.476E+00_fp, &
      5.176E+00_fp,4.994E+00_fp,4.884E+00_fp,4.832E+00_fp,4.791E+00_fp,4.760E+00_fp,4.736E+00_fp,6.368E+00_fp, &
      7.897E+00_fp,7.673E+00_fp,7.458E+00_fp,7.252E+00_fp/)

    Atmosphere(1)%Absorber(:,2) = &
    (/2.742E+00_fp,3.386E+00_fp,4.164E+00_fp,5.159E+00_fp,6.357E+00_fp,7.430E+00_fp,8.174E+00_fp,8.657E+00_fp, &
      8.930E+00_fp,9.056E+00_fp,9.077E+00_fp,8.988E+00_fp,8.778E+00_fp,8.480E+00_fp,8.123E+00_fp,7.694E+00_fp, &
      7.207E+00_fp,6.654E+00_fp,6.060E+00_fp,5.464E+00_fp,4.874E+00_fp,4.299E+00_fp,3.739E+00_fp,3.202E+00_fp, &
      2.688E+00_fp,2.191E+00_fp,1.710E+00_fp,1.261E+00_fp,8.835E-01_fp,5.551E-01_fp,3.243E-01_fp,1.975E-01_fp, &
      1.071E-01_fp,7.026E-02_fp,6.153E-02_fp,5.869E-02_fp,6.146E-02_fp,6.426E-02_fp,6.714E-02_fp,6.989E-02_fp, &
      7.170E-02_fp,7.272E-02_fp,7.346E-02_fp,7.383E-02_fp,7.406E-02_fp,7.418E-02_fp,7.424E-02_fp,7.411E-02_fp, &
      7.379E-02_fp,7.346E-02_fp,7.312E-02_fp,7.284E-02_fp,7.274E-02_fp,7.273E-02_fp,7.272E-02_fp,7.270E-02_fp, &
      7.257E-02_fp,7.233E-02_fp,7.167E-02_fp,7.047E-02_fp,6.920E-02_fp,6.803E-02_fp,6.729E-02_fp,6.729E-02_fp, &
      6.753E-02_fp,6.756E-02_fp,6.717E-02_fp,6.615E-02_fp,6.510E-02_fp,6.452E-02_fp,6.440E-02_fp,6.463E-02_fp, &
      6.484E-02_fp,6.487E-02_fp,6.461E-02_fp,6.417E-02_fp,6.382E-02_fp,6.378E-02_fp,6.417E-02_fp,6.482E-02_fp, &
      6.559E-02_fp,6.638E-02_fp,6.722E-02_fp,6.841E-02_fp,6.944E-02_fp,6.720E-02_fp,6.046E-02_fp,4.124E-02_fp, &
      2.624E-02_fp,2.623E-02_fp,2.622E-02_fp,2.622E-02_fp/)

    ! Some pretend cloud data
    k1 = 75  ! Pressure[k1] = 650.104hPa
    k2 = 79  ! Pressure[k2] = 741.693hPa
    Atmosphere(1)%Cloud(1)%Type = WATER_CLOUD
    Atmosphere(1)%Cloud(1)%Effective_Radius(k1:k2) = 20.0_fp ! microns
    Atmosphere(1)%Cloud(1)%Water_Content(k1:k2)    = 5.0_fp  ! kg/m^2

    ! Some pretend aerosol data
    k1 = 83  ! Pressure[k1] = 840.016hPa
    k2 = 85  ! Pressure[k2] = 891.679hPa
    Atmosphere(1)%Aerosol(1)%Type = DUST_AEROSOL
    Atmosphere(1)%Aerosol(1)%Effective_Radius(k1:k2) = 2.0_fp ! microns
    Atmosphere(1)%Aerosol(1)%Concentration(k1:k2)    = 5.0_fp ! kg/m^2


    ! 4a.2 Profile #2
    ! ---------------
    Surface(2)%Land_Coverage     = 0.25_fp
    Surface(2)%Land_Type         = SAND
    Surface(2)%Land_Temperature  = 275.0_fp
  
    Surface(2)%Water_Coverage    = 0.75_fp
    Surface(2)%Water_Type        = SEA_WATER
    Surface(2)%Water_Temperature = 272.0_fp

    Atmosphere(2)%Climatology    = US_STANDARD_ATMOSPHERE
    Atmosphere(2)%Absorber_Id    = (/ H2O_ID                 , O3_ID /)
    Atmosphere(2)%Absorber_Units = (/ MASS_MIXING_RATIO_UNITS, VOLUME_MIXING_RATIO_UNITS /)

    Atmosphere(2)%Level_Pressure = &
    (/0.714_fp,   0.975_fp,   1.297_fp,   1.687_fp,   2.153_fp,   2.701_fp,   3.340_fp,   4.077_fp, &
      4.920_fp,   5.878_fp,   6.957_fp,   8.165_fp,   9.512_fp,  11.004_fp,  12.649_fp,  14.456_fp, &
     16.432_fp,  18.585_fp,  20.922_fp,  23.453_fp,  26.183_fp,  29.121_fp,  32.274_fp,  35.650_fp, &
     39.257_fp,  43.100_fp,  47.188_fp,  51.528_fp,  56.126_fp,  60.990_fp,  66.125_fp,  71.540_fp, &
     77.240_fp,  83.231_fp,  89.520_fp,  96.114_fp, 103.017_fp, 110.237_fp, 117.777_fp, 125.646_fp, &
    133.846_fp, 142.385_fp, 151.266_fp, 160.496_fp, 170.078_fp, 180.018_fp, 190.320_fp, 200.989_fp, &
    212.028_fp, 223.441_fp, 235.234_fp, 247.409_fp, 259.969_fp, 272.919_fp, 286.262_fp, 300.000_fp, &
    314.137_fp, 328.675_fp, 343.618_fp, 358.967_fp, 374.724_fp, 390.893_fp, 407.474_fp, 424.470_fp, &
    441.882_fp, 459.712_fp, 477.961_fp, 496.630_fp, 515.720_fp, 535.232_fp, 555.167_fp, 575.525_fp, &
    596.306_fp, 617.511_fp, 639.140_fp, 661.192_fp, 683.667_fp, 706.565_fp, 729.886_fp, 753.627_fp, &
    777.790_fp, 802.371_fp, 827.371_fp, 852.788_fp, 878.620_fp, 904.866_fp, 931.524_fp, 958.591_fp, &
    986.067_fp,1013.948_fp,1042.232_fp,1070.917_fp,1100.000_fp/)
  
    Atmosphere(2)%Pressure = &
    (/0.838_fp,   1.129_fp,   1.484_fp,   1.910_fp,   2.416_fp,   3.009_fp,   3.696_fp,   4.485_fp, &
      5.385_fp,   6.402_fp,   7.545_fp,   8.822_fp,  10.240_fp,  11.807_fp,  13.532_fp,  15.423_fp, &
     17.486_fp,  19.730_fp,  22.163_fp,  24.793_fp,  27.626_fp,  30.671_fp,  33.934_fp,  37.425_fp, &
     41.148_fp,  45.113_fp,  49.326_fp,  53.794_fp,  58.524_fp,  63.523_fp,  68.797_fp,  74.353_fp, &
     80.198_fp,  86.338_fp,  92.778_fp,  99.526_fp, 106.586_fp, 113.965_fp, 121.669_fp, 129.703_fp, &
    138.072_fp, 146.781_fp, 155.836_fp, 165.241_fp, 175.001_fp, 185.121_fp, 195.606_fp, 206.459_fp, &
    217.685_fp, 229.287_fp, 241.270_fp, 253.637_fp, 266.392_fp, 279.537_fp, 293.077_fp, 307.014_fp, &
    321.351_fp, 336.091_fp, 351.236_fp, 366.789_fp, 382.751_fp, 399.126_fp, 415.914_fp, 433.118_fp, &
    450.738_fp, 468.777_fp, 487.236_fp, 506.115_fp, 525.416_fp, 545.139_fp, 565.285_fp, 585.854_fp, &
    606.847_fp, 628.263_fp, 650.104_fp, 672.367_fp, 695.054_fp, 718.163_fp, 741.693_fp, 765.645_fp, &
    790.017_fp, 814.807_fp, 840.016_fp, 865.640_fp, 891.679_fp, 918.130_fp, 944.993_fp, 972.264_fp, &
    999.942_fp,1028.025_fp,1056.510_fp,1085.394_fp/)

    Atmosphere(2)%Temperature = &
    (/256.186_fp, 252.608_fp, 247.762_fp, 243.314_fp, 239.018_fp, 235.282_fp, 233.777_fp, 234.909_fp, &
      237.889_fp, 241.238_fp, 243.194_fp, 243.304_fp, 242.977_fp, 243.133_fp, 242.920_fp, 242.026_fp, &
      240.695_fp, 239.379_fp, 238.252_fp, 236.928_fp, 235.452_fp, 234.561_fp, 234.192_fp, 233.774_fp, &
      233.305_fp, 233.053_fp, 233.103_fp, 233.307_fp, 233.702_fp, 234.219_fp, 234.959_fp, 235.940_fp, &
      236.744_fp, 237.155_fp, 237.374_fp, 238.244_fp, 239.736_fp, 240.672_fp, 240.688_fp, 240.318_fp, &
      239.888_fp, 239.411_fp, 238.512_fp, 237.048_fp, 235.388_fp, 233.551_fp, 231.620_fp, 230.418_fp, &
      229.927_fp, 229.511_fp, 229.197_fp, 228.947_fp, 228.772_fp, 228.649_fp, 228.567_fp, 228.517_fp, &
      228.614_fp, 228.861_fp, 229.376_fp, 230.223_fp, 231.291_fp, 232.591_fp, 234.013_fp, 235.508_fp, &
      237.041_fp, 238.589_fp, 240.165_fp, 241.781_fp, 243.399_fp, 244.985_fp, 246.495_fp, 247.918_fp, &
      249.073_fp, 250.026_fp, 251.113_fp, 252.321_fp, 253.550_fp, 254.741_fp, 256.089_fp, 257.692_fp, &
      259.358_fp, 261.010_fp, 262.779_fp, 264.702_fp, 266.711_fp, 268.863_fp, 271.103_fp, 272.793_fp, &
      273.356_fp, 273.356_fp, 273.356_fp, 273.356_fp/)

    Atmosphere(2)%Absorber(:,1) = &
    (/4.187E-03_fp,4.401E-03_fp,4.250E-03_fp,3.688E-03_fp,3.516E-03_fp,3.739E-03_fp,3.694E-03_fp,3.449E-03_fp, &
      3.228E-03_fp,3.212E-03_fp,3.245E-03_fp,3.067E-03_fp,2.886E-03_fp,2.796E-03_fp,2.704E-03_fp,2.617E-03_fp, &
      2.568E-03_fp,2.536E-03_fp,2.506E-03_fp,2.468E-03_fp,2.427E-03_fp,2.438E-03_fp,2.493E-03_fp,2.543E-03_fp, &
      2.586E-03_fp,2.632E-03_fp,2.681E-03_fp,2.703E-03_fp,2.636E-03_fp,2.512E-03_fp,2.453E-03_fp,2.463E-03_fp, &
      2.480E-03_fp,2.499E-03_fp,2.526E-03_fp,2.881E-03_fp,3.547E-03_fp,4.023E-03_fp,4.188E-03_fp,4.223E-03_fp, &
      4.252E-03_fp,4.275E-03_fp,4.105E-03_fp,3.675E-03_fp,3.196E-03_fp,2.753E-03_fp,2.338E-03_fp,2.347E-03_fp, &
      2.768E-03_fp,3.299E-03_fp,3.988E-03_fp,4.531E-03_fp,4.625E-03_fp,4.488E-03_fp,4.493E-03_fp,4.614E-03_fp, &
      7.523E-03_fp,1.329E-02_fp,2.468E-02_fp,4.302E-02_fp,6.688E-02_fp,9.692E-02_fp,1.318E-01_fp,1.714E-01_fp, &
      2.149E-01_fp,2.622E-01_fp,3.145E-01_fp,3.726E-01_fp,4.351E-01_fp,5.002E-01_fp,5.719E-01_fp,6.507E-01_fp, &
      7.110E-01_fp,7.552E-01_fp,8.127E-01_fp,8.854E-01_fp,9.663E-01_fp,1.050E+00_fp,1.162E+00_fp,1.316E+00_fp, &
      1.494E+00_fp,1.690E+00_fp,1.931E+00_fp,2.226E+00_fp,2.574E+00_fp,2.939E+00_fp,3.187E+00_fp,3.331E+00_fp, &
      3.352E+00_fp,3.260E+00_fp,3.172E+00_fp,3.087E+00_fp/)

    Atmosphere(2)%Absorber(:,2) = &
    (/3.035E+00_fp,3.943E+00_fp,4.889E+00_fp,5.812E+00_fp,6.654E+00_fp,7.308E+00_fp,7.660E+00_fp,7.745E+00_fp, &
      7.696E+00_fp,7.573E+00_fp,7.413E+00_fp,7.246E+00_fp,7.097E+00_fp,6.959E+00_fp,6.797E+00_fp,6.593E+00_fp, &
      6.359E+00_fp,6.110E+00_fp,5.860E+00_fp,5.573E+00_fp,5.253E+00_fp,4.937E+00_fp,4.625E+00_fp,4.308E+00_fp, &
      3.986E+00_fp,3.642E+00_fp,3.261E+00_fp,2.874E+00_fp,2.486E+00_fp,2.102E+00_fp,1.755E+00_fp,1.450E+00_fp, &
      1.208E+00_fp,1.087E+00_fp,1.030E+00_fp,1.005E+00_fp,1.010E+00_fp,1.028E+00_fp,1.068E+00_fp,1.109E+00_fp, &
      1.108E+00_fp,1.071E+00_fp,9.928E-01_fp,8.595E-01_fp,7.155E-01_fp,5.778E-01_fp,4.452E-01_fp,3.372E-01_fp, &
      2.532E-01_fp,1.833E-01_fp,1.328E-01_fp,9.394E-02_fp,6.803E-02_fp,5.152E-02_fp,4.569E-02_fp,4.855E-02_fp, &
      5.461E-02_fp,6.398E-02_fp,7.205E-02_fp,7.839E-02_fp,8.256E-02_fp,8.401E-02_fp,8.412E-02_fp,8.353E-02_fp, &
      8.269E-02_fp,8.196E-02_fp,8.103E-02_fp,7.963E-02_fp,7.741E-02_fp,7.425E-02_fp,7.067E-02_fp,6.702E-02_fp, &
      6.368E-02_fp,6.070E-02_fp,5.778E-02_fp,5.481E-02_fp,5.181E-02_fp,4.920E-02_fp,4.700E-02_fp,4.478E-02_fp, &
      4.207E-02_fp,3.771E-02_fp,3.012E-02_fp,1.941E-02_fp,9.076E-03_fp,2.980E-03_fp,5.117E-03_fp,1.160E-02_fp, &
      1.428E-02_fp,1.428E-02_fp,1.428E-02_fp,1.428E-02_fp/)
  
    ! Some pretend cloud data
    Atmosphere(2)%Cloud(1)%Type = RAIN_CLOUD
    k1 = 73  ! Pressure[k1] = 606.847hPa
    k2 = 90  ! Pressure[k2] =1028.025hPa
    Atmosphere(2)%Cloud(1)%Effective_Radius(k1:k2) = 1000.0_fp ! microns
    Atmosphere(2)%Cloud(1)%Water_Content(k1:k2)    =    5.0_fp ! kg/m^2

    ! Some pretend aerosol data
    Atmosphere(2)%Aerosol(1)%Type = ORGANIC_CARBON_AEROSOL
    k1 = 48  ! Pressure[k1] = 206.459hPa
    k2 = 55  ! Pressure[k2] = 293.077hPa
    Atmosphere(2)%Aerosol(1)%Effective_Radius(k1:k2) = 0.09_fp ! microns
    Atmosphere(2)%Aerosol(1)%Concentration(k1:k2)    = 0.03_fp ! kg/m^2
    k1 = 78  ! Pressure[k1] = 718.163hPa
    k2 = 86  ! Pressure[k2] = 918.130hPa
    Atmosphere(2)%Aerosol(1)%Effective_Radius(k1:k2) = 0.15_fp ! microns
    Atmosphere(2)%Aerosol(1)%Concentration(k1:k2)    = 0.06_fp ! kg/m^2

  END SUBROUTINE Load_AtmSfc_Data


  SUBROUTINE SignalFile_Create()
    CHARACTER(256) :: Filename
    INTEGER :: fid
    Filename = RESULTS_PATH//TRIM(Sensor_Id)//'.signal'
    fid = Get_Lun()
    OPEN( fid, FILE = Filename )
    WRITE( fid,* ) TRIM(Filename)
    CLOSE( fid )
  END SUBROUTINE SignalFile_Create
  
END PROGRAM Example1_Simple
