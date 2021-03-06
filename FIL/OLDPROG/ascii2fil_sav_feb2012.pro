FUNCTION CHAIN2IND,first,chainc,xsize,ysize
  
   ind=first[1]*LONG(xsize)+first[0]
   length=STRLEN(chainc)
   ;set=[1,xsize+1,xsize,xsize-1,-1,-xsize-1,-xsize,-xsize+1];trigo debut droite
   set=[-1,-xsize-1,-xsize,-xsize+1,1,xsize+1,xsize,xsize-1];trigo debut gauche 
   newind=ind
   FOR jj=0,length-1 DO BEGIN
      next=FIX(STRMID(chainc,jj,1))
      newind=newind+set[next]
      ind=[ind,newind]
   ENDFOR      
   
RETURN,ind
END


FUNCTION ASCII2FIL,FILE=file,SKE=ske,BOUND=bound,DISK_DISP=disk_disp,PREPRO_DISP=prepro_disp,ORIGINAL_DISP=original_disp,IM_2K=im_2k,NEW_NORM=new_norm

  ;From ascii files written by efr_fil2ascii.pro, extract boundary and/or
  ;skeleton positions to superimpose them on a Sun shape defined below:
  ;The standard Sun : sunrad 420 , centered at (511.5,511.5)
  ;OR, for 2K*2K images : sunrad 840 , centered at (1023.5,1023.5)
  ;
  ;KEYWORDS:
  ;  FILE: name and path of the ascii file '*_feat.txt'
  ;  SKE: extract skeleton data
  ;  BOUND: extract boundary data
 ; ;  DISK_DISP: superimpose on a sun disk
 ; ;  PREPRO_DISP: superimpose on the preprocessed sun image
 ; ;  ORIGINAL_DISP: superimpose on the original image
  ;  IM_2K: 2048*2048 images (BBSO for example) instead of 1024*1024
  ;  NEW_NORM:

   maskval  = 0b
   disval = 1b
   maxval=1b

  ;### change the following path to your path (for the dialog pickfile):
  path='/home/fuller/poub/SAV/FIL/DAILY_ASCII/'

  ;### Select a file if none was specified with FILE keyword
   IF NOT KEYWORD_SET(file) THEN BEGIN
     file = DIALOG_PICKFILE(PATH=path,FILTER='*_feat.txt')
   ENDIF 

   ;### other filenames deduced from main one
   ;fbase = FILE_BASENAME(file,'_feat.txt')
   ;normf = fbase+'_pp.txt'
   ;initf = fbase+'_obs.txt'
   ;;pos  = STRPOS(file,'_feat.txt')
   ;;normf= STRMID(file,0,pos)+'_pp.txt'
   ;;initf= STRMID(file,0,pos)+'_obs.txt'

   ;### Read the ascii files
   tabfeat = RD_TFILE(file,/AUTOCOL,DELIM=';',/HSKIP,HEADER=headf)
   headf  = STRSPLIT(headf,';',/EXTRACT)

   ;tabfeat = RD_TFILE(file,38,DELIM=';',/HSKIP,HEADER=head)
   ;tabnorm = RD_TFILE(normf,13,DELIM=';',/HSKIP,HEADER=head)
   ;tabinit = RD_TFILE(initf,23,DELIM=';',/HSKIP,HEADER=head)
   ;IF (SIZE(tabfeat))[0] EQ 1 THEN tabfeat = REFORM(tabfeat,38,1,/OVER)
   ;IF (SIZE(tabnorm))[0] EQ 1 THEN tabnorm = REFORM(tabnorm,13,1,/OVER)
   ;IF (SIZE(tabinit))[0] EQ 1 THEN tabinit = REFORM(tabinit,23,1,/OVER)
   ;fitsf = tabfeat[37]
   ;fitsori = tabinit[19]


  ;Build a sun shape
   rsun = 420
   Xsiz = 1024
   Ysiz = 1024
   IF KEYWORD_SET(IM_2K) THEN BEGIN
      rsun = 840
      Xsiz = 2048
      Ysiz = 2048
   ENDIF
   input = BYTARR(Xsiz,Ysiz)+1b
   ;mask_SUBS   = WHERE(input*0+1)
   ;mask_SUBS_Y = mask_SUBS /   Xsiz
   ;mask_SUBS_X = mask_SUBS MOD Xsiz
   ;mask_DIST   = SQRT((mask_SUBS_X-(Xsiz-1)/2)^2 + (mask_SUBS_Y-(Ysiz-1)/2)^2) 
   ;mask_0      = WHERE(mask_DIST LE rsun,nmsk0)
   mask_0 = EFR_ROUNDMASK(Xsiz,Ysiz,0.,rsun,COMP=mask_comp)
   input[mask_0] = maskval

  ; IF KEYWORD_SET(disk_disp) OR KEYWORD_SET(prepro_disp) OR KEYWORD_SET(original_disp) THEN window,/free,xs=1024,ys=1024


   ;IF KEYWORD_SET(prepro_disp) THEN BEGIN
   ;   input=BYTSCL(READFITS(fitsf))
   ;   disval=0b
   ;   maxval=max(input)
   ;ENDIF

   ;IF KEYWORD_SET(original_disp) THEN BEGIN
      ;fitsori='/data2/fuller/FITS/bbso_halph_fr_20020716_165911.fts'
   ;   imfits=READFITS(fitsori,h0)
   ;   toto=size(imfits)
   ;   IF toto[3] EQ 5 THEN imfits=imfits[*,*,2]
   ;   input=BYTSCL(imfits)
   ;   maxval=max(imfits)
   ;   print,h0
   ;   disval=255b

  ;####recuperation des valeurs originales du fits
      cdelt1ori = tabinit[15];2.33
      cdelt2ori = tabinit[16];2.31
;      r_sun_ori = tabinit[12]
      naxis1ori = tabinit[10]
      centx_ori = tabinit[13];461.95
      centy_ori = tabinit[14];451.75  

   ENDIF   
 
   ngd = (SIZE(tabfeat))[2]

  ;####recuperation des valeurs utilisees lors de l'encodage (chain code)
   cdelt1srce = tabnorm[3,0]
   cdelt2srce = tabnorm[4,0]
   IF KEYWORD_SET(NEW_NORM) THEN BEGIN ;les fichiers ascii norm (locaux) on ete augmentes de 5 valeurs (sep2010) (naxis1,naxis2,etc)
                                       ;pour s'adapter au fait que les fichiers preprocesses peuvent etre differents de 1024*1024 
      cdelt1srce = tabnorm[8,0]
      cdelt2srce = tabnorm[9,0]
   ENDIF
   naxis1srce = Xsiz
   naxis2srce = Xsiz


  FOR ii=0,ngd-1 DO BEGIN

    IF KEYWORD_SET(SKE) THEN BEGIN
      ;####calcul pour tous les points de la position en pixels
      ;####de l'origine puis de la chaine (skeleton)
      first_pt_arcsx = tabfeat[31,ii]
      first_pt_arcsy = tabfeat[32,ii]
      xpos = FIX(DOUBLE((Xsiz-1)/2.) + first_pt_arcsx/DOUBLE(cdelt1srce))
      ypos = FIX(DOUBLE((Xsiz-1)/2.) + first_pt_arcsy/DOUBLE(cdelt2srce))
      schain = tabfeat[35,ii]
      indices = CHAIN2IND([xpos,ypos],schain,naxis1srce,naxis2srce)
      input[indices]=disval
      input[xpos,ypos]=disval
    ENDIF

    IF KEYWORD_SET(BOUND) THEN BEGIN    
      ;####calcul pour tous les points de la position en pixels
      ;####de l'origine puis de la chaine (boundary)
      first_pt_arcsx_b = tabfeat[23,ii]
      first_pt_arcsy_b = tabfeat[24,ii]
      xpos_b = FIX(DOUBLE((Xsiz-1)/2.) + first_pt_arcsx_b/DOUBLE(cdelt1srce))
      ypos_b = FIX(DOUBLE((Xsiz-1)/2.) + first_pt_arcsy_b/DOUBLE(cdelt2srce))
      schain_b = tabfeat[33,ii]
      indices_b = CHAIN2IND([xpos_b,ypos_b],schain_b,naxis1srce,naxis2srce)
      IF KEYWORD_SET(original_disp) THEN BEGIN
         xpos_b = FIX(DOUBLE(centx_ori) + first_pt_arcsx_b/DOUBLE(cdelt1ori))
         ypos_b = FIX(DOUBLE(centy_ori) + first_pt_arcsy_b/DOUBLE(cdelt2ori))
         FOR jj=0,n_elements(indices_b)-1 DO BEGIN
            ptarcsx = ((indices_b[jj] MOD Xsiz) - (Xsiz-1)/2d)*DOUBLE(cdelt1srce)
            ptarcsy = ((indices_b[jj] / Xsiz) - (Xsiz-1)/2d)*DOUBLE(cdelt2srce)
            xpos_jj = FIX(DOUBLE(centx_ori) + ptarcsx/DOUBLE(cdelt1ori))
            ypos_jj = FIX(DOUBLE(centy_ori) + ptarcsy/DOUBLE(cdelt2ori))
            ;input[xpos_jj,ypos_jj]=disval
            indices_b[jj] = xpos_jj + 1L*ypos_jj*naxis1ori                     
         ENDFOR
      ENDIF
      input[indices_b]=disval
      input[xpos_b,ypos_b]=disval  
    ENDIF

  ENDFOR

  IF KEYWORD_SET(disk_disp) OR KEYWORD_SET(prepro_disp) OR KEYWORD_SET(original_disp) THEN TVSCL,input

RETURN,input
 
END
