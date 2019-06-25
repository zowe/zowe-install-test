//IEBUPDTE JOB                                                  
//*                                                                             
//* Zowe Open Source Project                                                    
//* This JCL will prepare the download-package for installation.                
//*                                                                             
//* Caution: This is neither a JCL procedure nor a complete job.                
//*          Therefore, before using this sample, you will need to              
//*          make changes as described.                                         
//*                                             
//         EXPORT SYMLIST=(HLQ)                         
//*                                                                             
//*   product FMID                                                              
//*         SET FMID=AZWE001                                                     
//*   HLQ where to store GIMUNZIP output                                        
//         SET HLQ=ZOE
//*                                                                             
//******************************************************************            
//* Converting the download-package on your desktop to the data sets            
//* used by SMP/E to install the function consists of the following             
//* steps:                                                                      
//* 1. (optional) Create and mount a z/OS UNIX file system to hold              
//*    the download-package when it is uploaded to the host. Sample             
//*    job FILESYS (commented out) is provided in this file.                    
//* 2. Upload the download-package to the host. Sample FTP instructions         
//*    are provided in this file.                                               
//* 3. Extract the uploaded download-package to create the data sets            
//*    used by SMP/E to install the function. This file is the sample           
//*    job for that.                                                            
//*                                                                             
//******************************************************************            
//*                                                                             
//* Make the following updates before using this JCL when you have              
//* copied it to your MVS system                                                
//*                                                                             
//*   - Provide valid job card information                                      
//*       Note that there are two job cards (EXTRACT and FILESYS) in            
//*       this JCL                                                              
//*                                                                             
//*   - Change:                                                                 
//*       @PREFIX@                                                              
//*       ----+----1----+----2----+                                             
//*                  - To your desired data set name prefix                     
//*                  - Maximum length is 25 characters                          
//*                  - This value is used for the names of the                  
//*                    data sets extracted from the download-package            
//*       @zfs_path@                                                            
//*       ----+----1----+----2----+----3----+----4----+----5                    
//*                  - To the absolute z/OS UNIX path for the download          
//*                    package (starting with /)                                
//*                  - Maximum length is 50 characters                          
//*                  - Do not include a trailing /                              
//*       @zfs_dsn@                                                             
//*                  - To your file system data set name                        
//*                  - This is used only if you intend to run the               
//*                    commented-out job, FILESYS                               
//*                                                                             
//******************************************************************            
//*                                                                             
//* Step 1. Create a directory for the download-package                         
//*                                                                             
//* You can either create a new z/OS UNIX file system (zFS) or create           
//* a new directory in an existing file system. The directory that              
//* will contain the download-package must reside on the z/OS system            
//* where the function will be installed.                                       
//*                                                                             
//* To create a new file system, and directory, for the download                
//* package, you can use the sample JCL (FILESYS), which follows.               
//* Copy and paste the sample JCL into a separate data set, uncomment           
//* the job, and modify the job to update required parameters before            
//* submitting it.                                                              
//*                                                                             
//*-----------------------------------------------------------------   
//STEP1    EXEC PGM=IEBUPDTE,PARM=NEW
//SYSPRINT DD   SYSOUT=*
//SYSUT2   DD DISP=(MOD,CATLG),DSN=&HLQ..INSTALL.JCL,                                  
//            SPACE=(TRK,(1,1,1)),UNIT=SYSALLDA,                                  
//            DCB=(DSORG=PO,RECFM=FB,LRECL=80,BLKSIZE=3120) 
//SYSIN    DD   DATA,DLM=ZZ
./        ADD   NAME=FILESYS
//FILESYS  JOB <job parameters>                                             
//*                                                                         
//***************************************************************           
//* This job must be updated to reflect your environment.                   
//* This sample:                                                            
//*   . Allocates a new z/OS UNIX file system                               
//*   . Creates a mount point directory                                     
//*   . Mounts the file system                                              
//*                                                                         
//* - Provide valid job card information                                    
//* - Change:                                                               
//*   @zfs_path@                                                            
//*   ----+----1----+----2----+----3----+----4----+----5                    
//*              - To the absolute z/OS UNIX path for the download          
//*                package (starting with /)                                
//*              - Maximum length is 50 characters                          
//*              - Do not include a trailing /                              
//*   @zfs_dsn@                                                             
//*              - To your file system data set name                        
//*                                                                         
//* Your userid MUST be defined as a SUPERUSER to successfully              
//* run this job                                                            
//*                                                                         
//***************************************************************           
//*                                                                         
//CREATE   EXEC PGM=IDCAMS,REGION=0M,COND=(0,LT)                            
//SYSPRINT DD SYSOUT=*                                                      
//SYSIN    DD *                                                             
   DEFINE CLUSTER ( -                                                        
          NAME(@zfs_dsn@) -                                                  
          TRK(17124 90) -                                                    
        /*VOLUME(volser)*/ -                                                 
          LINEAR -                                                           
          SHAREOPTIONS(3) -                                                  
          )   
//         SET ZFSDSN='@zfs_dsn@'                                           
//FORMAT   EXEC PGM=IOEAGFMT,REGION=0M,COND=(0,LT),                         
//            PARM='-aggregate &ZFSDSN -compat'                             
//*STEPLIB  DD DISP=SHR,DSN=IOE.SIOELMOD        before z/OS 1.13            
//*STEPLIB  DD DISP=SHR,DSN=SYS1.SIEALNKE       from z/OS 1.13              
//SYSPRINT DD SYSOUT=*                                                      
//*                                                                         
//MOUNT    EXEC PGM=IKJEFT01,REGION=0M,COND=(0,LT)                          
//SYSEXEC  DD DISP=SHR,DSN=SYS1.SBPXEXEC                                    
//SYSTSPRT DD SYSOUT=*                                                      
//SYSTSIN  DD *                                                             
   PROFILE MSGID WTPMSG                                                      
   oshell umask 0022; +                                                      
     mkdir -p @zfs_path@                                                     
   MOUNT +                                                                   
     FILESYSTEM('@zfs_dsn@') +                                               
     MOUNTPOINT('@zfs_path@') +                                              
     MODE(RDWR) TYPE(ZFS) PARM('AGGRGROW')
//     
./        ADD   NAME=UNPAX
//UNPAX JOB
//*-----------------------------------------------------------------            
//*                                                                             
//******************************************************************            
//*                                                                             
//* Step 2. Make the download-package files available to the host               
//*                                                                             
//* The two files to be uploaded and processed on the host system are:          
//*   a) &FMID&README (this file)                                               
//*      This is a sample job that executes the z/OS UNIX System                
//*      Services pax command to extract package archives. This job             
//*      also executes the GIMUNZIP program to expand the package               
//*      archives so that the data sets can be processed by SMP/E.              
//*                                                                             
//*   b) &FMID..pax.Z                                                           
//*      This pax archive file holds the SMP/E MCS and RELFILEs.                
//*                                                                             
//*      IMPORTANT:                                                             
//*      This file must reside in the directory created in Step 1.              
//*                                                                             
//* There are many ways to transfer the files or make them available            
//* to the z/OS system where the package will be installed. An example          
//* using FTP is provided below. This assumes that the z/OS host is             
//* configured as an FTP host/server and that the workstation is an             
//* FTP client.                                                                 
//*                                                                             
//*   IMPORTANT:                                                                
//*   The &FMID..pax.Z                                                          
//*   file must be uploaded to the z/OS driving system                          
//*   in binary format, or the subsequent UNPAX step will fail.                 
//*                                                                             
//* Sample FTP upload scenario:                                                 
//*                                                                             
//*   From your workstation COMMAND PROMPT panel                                
//*   - enter:  ftp your_host_system_name                                       
//*   - login with your userid and password                                     
//*   - enter:  cd @zfs_path@                                                   
//*   - enter:  ascii                                                           
//*   - enter:  put &FMID&README                                                
//*   - enter:  binary                                                          
//*   - enter:  put &FMID..pax.Z                                                
//*   - enter:  quit                                                            
//*                                                                             
//******************************************************************            
//*                                                                             
//* Step 3. After you have uploaded the files to your host system               
//*                                                                             
//* a. Customize the job provided in                                            
//*    &FMID&README                                                             
//*    - This is file you are reading                                           
//*                                                                             
//* b. Submit the modified job                                                  
//*    This job will create the SMPMCS and RELFILE data sets for use            
//*    by the SMP/E RECEIVE job.                                                
//*    - The UNPAX step expand the download file into the individual            
//*      archive files that make up the download-package. The component         
//*      archive files are expanded into the same directory where               
//*      the download file resides.                                             
//*    - The GIMUNZIP step step extracts the FMID(s) and related                
//*      materials from the archive files and places them in data sets.         
//*                                                                             
//* c. Install the function via SMP/E using the instructions in the             
//*    program directory.                                                       
//*                                                                             
//* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -             
//*   - Change:                                                                 
//*       @PREFIX@                                                              
//*       ----+----1----+----2----+                                             
//*                  - To your desired data set name prefix                     
//*                  - Maximum length is 25 characters                          
//*                  - This value is used for the names of the                  
//*                    data sets extracted from the download-package            
//*       @zfs_path@                                                            
//*       ----+----1----+----2----+----3----+----4----+----5                    
//*                  - To the absolute z/OS UNIX path for the download          
//*                    package (starting with /)                                
//*                  - Maximum length is 50 characters                          
//*                  - Do not include a trailing /                              
//*                                                                             
//* Note: If the 'oshell' command has a RC=256 and message                      
//* "pax: checksum error on tape (got ee2e, expected 0)", then the              
//* &FMID..pax.Z                                                                
//* archive file was not uploaded to the host in binary format.                 
//UNPAX    EXEC PGM=IKJEFT01,REGION=0M,COND=(0,LT)                              
//SYSEXEC  DD DISP=SHR,DSN=SYS1.SBPXEXEC                                        
//SYSTSPRT DD SYSOUT=*                                                          
//SYSTSIN  DD *                                                                 
  oshell cd @zfs_path@/ ; +                                                     
    pax -rvf &FMID..pax.Z                                                       
//*                                                                             
//* Note: GIMUNZIP allocates data sets to match the definitions of              
//* the original data sets. You may encounter errors if your SMS ACS            
//* routines alter the attributes used by GIMUNZIP.                             
//* If this occurs, specify a non-SMS managed volume for the                    
//* GIMUNZIP allocation of the data sets. For example:                          
//* <ARCHDEF archid="..."                                                       
//*          storclas="storage_class" volume="data_set_volume"                  
//*          newname="..."/>
//                                                    
./        ADD   NAME=GIMUNZIP
//GIMUNZIP JOB        
//GIMUNZIP EXEC PGM=GIMUNZIP,REGION=0M,COND=(0,LT)                              
//*STEPLIB  DD DISP=SHR,DSN=SYS1.MIGLIB                                         
//SYSUT3   DD UNIT=SYSALLDA,SPACE=(CYL,(50,10))                                 
//SYSUT4   DD UNIT=SYSALLDA,SPACE=(CYL,(25,5))                                  
//SMPOUT   DD SYSOUT=*                                                          
//SYSPRINT DD SYSOUT=*                                                          
//SMPDIR   DD PATHDISP=KEEP,                                                    
// PATH='@zfs_path@/'                                                           
//SYSIN    DD *                                                                 
<GIMUNZIP>                                                                      
<ARCHDEF archid="&FMID..SMPMCS"                                                 
         newname="@PREFIX@.&FMID..SMPMCS"/>                                     
<ARCHDEF archid="&FMID..F1"                                                     
         newname="@PREFIX@.&FMID..F1"/>                                         
<ARCHDEF archid="&FMID..F2"                                                     
         newname="@PREFIX@.&FMID..F2"/>                                         
<ARCHDEF archid="&FMID..F3"                                                     
         newname="@PREFIX@.&FMID..F3"/>                                         
<ARCHDEF archid="&FMID..F4"                                                     
         newname="@PREFIX@.&FMID..F4"/>                                         
</GIMUNZIP>                                                                     
//                                                                             
./ ENDUP
/*
ZZ
//