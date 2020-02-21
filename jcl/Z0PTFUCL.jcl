//Z0PTFUCL JOB 
//*                                                            
//* update active CSI                                          
//*                                                            
//         EXPORT SYMLIST=*                                    
//         SET SMPE=CUST.ZOWE.SMPE                             
//         SET TLIB=SMPTZN                                     
//         SET DLIB=SMPDZN                                     
//         SET VOLSER=ZOWE02                                   
//*                                                            
//UCLIN    EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)               
//SMPLOG   DD SYSOUT=*                                         
//SMPCSI   DD DISP=OLD,DSN=&SMPE..CSI                          
//SMPCNTL  DD *,SYMBOLS=JCLONLY                                
   SET BOUNDARY(GLOBAL) .                                      
   UCLIN .                                                     
   REP DDDEF(SYSUT1)   CYL SPACE(20,300) DIR(50) UNIT(SYSALLDA)        
   VOLUME(&VOLSER) .                                           
   ENDUCL                                                      
   .                                                           
   SET BOUNDARY(&TLIB) .                                       
   UCLIN .                                                     
   REP DDDEF(SMPWRK6)  CYL SPACE(20,200) DIR(50) UNIT(SYSALLDA)        
   VOLUME(&VOLSER) .                                           
   ENDUCL                                                      
   .                                                           
   SET BOUNDARY(&DLIB) .                                       
   UCLIN .                                                     
   REP DDDEF(SMPWRK6)  CYL SPACE(20,200) DIR(50) UNIT(SYSALLDA)        
   VOLUME(&VOLSER) .                                           
   ENDUCL                                                      
   .                                                           
//*                                                            