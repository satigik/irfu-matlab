function ret = caa_get_bursts(filename, burst_plot)
%caa_get_bursts(filename) produce and plot Cluster burst data from the raw data
%
% data = caa_get_bursts(filename, plotflag)
%
% Input:
%   filename   : burst data file name
%   burst_plot : generate plot 0=off 1=on (default off)
%
% Burst files are read from directory /data/cluster/burst/
% Plot files are saved in directory $HOME/figures/
% 
% Example: 
%       caa_get_bursts('070831101839we.03')
%

error(nargchk(1,2,nargin));
if nargin < 2
    burst_plot = 0;
end
old_pwd = pwd;

ret=1;

% WARNING: Do NOT use 1 for this on server L1 data
fetch_efw_data=0; % must be 1 if no efw data in current directory

cord_plot=0;
plot_save=1;
plotpath=[getenv('HOME') '/figures/'];

flag_save = 1;
save_list = '';
DBNO='db:9';
dt=30; %Sets the time interval for the data retrieval
no_data=0;
B_DT = 300;
B_DELTA = 60;
cp = ClusterProc;

GSE=[];
GSM=[];
cord=1;
burstreadbytes=44;

    fns=size(filename,2);
    DP = c_ctl(0,'data_path');
    fid=fopen([DP '/burst/' filename],'rb'); % opens the binary file for reading
    if fid==-1
        error(['Can not find burst file ' filename ' in ' DP '/burst']);
        cd(old_pwd);
        return;
    end
        
    fseek(fid,128,0); % skip first 128 bytes
    % run on intel little endian read
    data(fns+1:fns+burstreadbytes,1) = fread(fid, burstreadbytes, 'uint8=>uint8', 'ieee-be'); % start at 18 due to filname byte length (17)
    fclose(fid);

    delete('mEFWburs*.mat') %Remove old files
%    delete('*.mat') %Removes old files. THIS IS DANGEROUS!!! FIX ME!

    cl_id=str2double(filename(end)); %Get the satellite number      
	fname=irf_ssub([plotpath 'p?-c!'],filename(1:12),cl_id); %Sets the name that will be used to save the plots
    fnshort=filename;
    s=filename;
	full_time = iso2epoch(['20' s(1:2) '-' s(3:4) '-' s(5:6) 'T' s(7:8) ':' s(9:10) ':' s(11:12) 'Z']);
    start_time=full_time;
    st=full_time;

    dirs = caa_get_subdirs(st, 90, cl_id);
    if isempty(dirs)
        irf_log('proc',['Can not find L1 data dir for ' s]);
        return;
    end
    found=false;
    for i=size(dirs,2):-1:1 % find start time directory
        d=dirs{i}(end-12:end);
        dtime=iso2epoch([d(1:4) '-' d(5:6) '-' d(7:8) 'T' d(10:11) ':' d(12:13) ':00Z']);
        if dtime<=start_time
            found=true;
            break;
        end
    end
    if ~found
        irf_log('proc','iburst start time does not match any L1 data dir');
        return;
    end
    cd(dirs{i});

    date = fromepoch(full_time);
    sp = [pwd() '/' irf_fname(full_time)];  
    cdb=ClusterDB(DBNO,[ DP '/burst'],'.');
    %Sets the variables for gathering normal mode data   
    vars0 = {'tmode','fdm','efwt','ibias','p','e','a','sax','r','v','bfgm','bsc'};
	%Sets the variables thats needed for burst data.
    vars11 = {'whip','sweep','bdump','probesa','p','ps' 'dies','die','pburst','dieburst','dibsc','dibscburst'};
	%Scans the correct line from the text file to be used later.
%	data=sscanf(tline,'%s %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x');%,fname,&bcode,&bfreq,&btrig,&bchirp,&bpages,&bthrsh0,&bp0,&bp1,&bp2,&bp3,&st[0],&st[1],&st[2],&st[3],&st[4],&vt[0], &vt[1], &vt[2], &vt[3], &vt[4],&et[0],&et[1],&et[2],&et[3],&et[4],&sa[0],&sa[1],&sa[2],&ea[0],&ea[1],&ea[2],&lr[0],&lr[1],&lr[2],&spare1,&spare2,&f[0],&f[1],&f[2],&f[3],&f[4],&f[5],&f[6],&f[7]))
    filename=irf_ssub([ DP '/burst/?'],filename)
    dec2bin(data(19),8);
    OUT = c_efw_burst_geth(filename);
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%    Getting frequency and number of parameters    %%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %getting the information from the data and makes the corresponding number smaller.
    fff = bitand(data(19),7);
    ss = bitand(data(19),48);
    SS = bitshift(ss,-4);

    switch SS
        case 0,
            switch fff
                case 0, 
                    output=[450  8];
                case 1,
                    output=[900 8];
                case 2, 
                    output=[2250 8];
                case 3,
                    output=[4500 8];
                case 4, 
                    output=[9000 4];
                case 7,
                    output=[25000 2];
                otherwise
                    output=[0];
            end
            
        case 1
            if fff==5
                output=[18000 2];
            else
                error('bad fff');
            end    
            
        case 2
            switch fff
                case 4
                    output=[9000 8];
                case 5
                    output=[18000 2];
                otherwise
                    output=[0];
            end
            
        case 3
            switch fff
                case 0
                    output=[450 16];
                case 1
                    output=[900 16];
                case 2
                    output=[2250 16];
                case 3
                    output=[4500 16];
                case 4
                    output=[9000 8];
                case 5
                    output=[18000 4];
                case 6
                    output=[36000 2];
                otherwise
                    output=[0];
            end
    end
    
    i=1;
    iii=2;
    ii=54;
%    vars=zeros(output(1,2),4);
    varsb={};
    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                                %%%%%%%%%%%%%%%%%%%%%%%
%%%%%    Getting information about the burst data    %%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                                %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    madc0={ 'V1L' 'V1M' 'V1H' 'V1U' 'V3L' 'V3M' 'V3H' 'V3U'...
            'V12M' 'V12M' 'SCX' 'SCZ' 'BAD' };
    madc1={ 'V2L' 'V2M' 'V2H' 'V2U' 'V4L' 'V4M' 'V4H' 'V4U'...
            'V43M' 'V12H' 'SCY' 'BP12' 'BAD' };

    while length(data)>=ii && data(ii)~=63
        
        adc0 = bitand(data(ii),15);
        adc1 = bitand(data(ii),240);
        adc1 = bitshift(adc1,-4);
        adc1 = bitor(bitand(adc0,8),bitand(adc1,7));
        
        if adc0>11 || adc0<0
            adc0=11;
        end
        varsb{i} = madc0{adc0+1};

        if adc1>11 || adc1<0
            adc1=11;
        end
        varsb{iii} = madc1{adc1+1};
        
        i=i+2;
        ii=ii+1;
        iii=iii+2;

    end
%    x=char(vars(2,2));
%    vars1 = char(vars);
    
%    [s,l] = size(vars);
    varsbsize=size(varsb,2);
    if varsbsize==2
        varsbsize
        pause;
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%    Getting the burst data from ISDAT database    %%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    probe_list=1:4;
    do_burst=1;
%%%%%%%%%%%%%%%%%%%%%%%%% PROBE MAGIC %%%%%%%%%%%%%%%%%%%%%%
	switch cl_id
		case 1
			if start_time>toepoch([2009 10 14 07 00 00]) || ...
					(start_time>toepoch([2009 04 19 00 00 00]) && start_time<toepoch([2009 05 07 00 00 00]))
				% p1 and p4 failure
				probe_list = 2:3;
				irf_log('dsrc',sprintf('p1 and p4 are BAD on sc%d',cl_id))
			elseif start_time>toepoch([2001 12 28 03 00 00]) 
				% p1 failure
				probe_list = 2:4;
				irf_log('dsrc',sprintf('p1 is BAD on sc%d',cl_id))
			elseif ( (start_time>=toepoch([2001 04 12 03 00 00]) && start_time<toepoch([2001 04 12 06 00 00])) || ...
					(  start_time>=toepoch([2001 04 14 06 00 00]) && start_time<toepoch([2001 04 16 15 00 00])) || ...
					(  start_time>=toepoch([2001 04 18 03 00 00]) && start_time<toepoch([2001 04 20 09 00 00])) || ...
					(  start_time>=toepoch([2001 04 21 21 00 00]) && start_time<toepoch([2001 04 22 03 00 00])) || ...
					(  start_time>=toepoch([2001 04 23 09 00 00]) && start_time<toepoch([2001 04 23 15 00 00])) )
				% The bias current is a bit too large
				% on p3 and p4 on C1&2 in April 2001.
				% Ignore p3, p4 and p34 and only use p1, p2 and p12.
				% Use only complete 3-hour intervals to keep it simple.
				probe_list = [1 2];
				irf_log('dsrc',sprintf('Too high bias current on p3&p4 sc%d',cl_id));
			end
		case 2
			if start_time>=toepoch([2007 06 01 17 20 00])
				% We use 180 Hz filter
				if ~do_burst, param={'180Hz'}; end
				irf_log('dsrc',sprintf('using 180Hz filter on sc%d',cl_id))
				probe_list = [2 4];
				irf_log('dsrc',sprintf('p1 is BAD on sc%d',cl_id))
			elseif start_time>=toepoch([2007 05 13 03 23 48])
				probe_list = [2 4];
				irf_log('dsrc',sprintf('p1 is BAD on sc%d',cl_id))
			elseif start_time+dt>toepoch([2001 07 23 13 54 18]) && ~do_burst
				% 10Hz filter problem on C2 p3
				% Any changes should also go to ClusterProc/getData/probesa
				probe_list = [1 2 4];
				irf_log('dsrc',sprintf('10Hz filter problem on p3 sc%d',cl_id))
			elseif ( (start_time>=toepoch([2001 04 09 21 00 00]) && start_time<toepoch([2001 04 10 06 00 00])) || ...
					(  start_time>=toepoch([2001 04 10 09 00 00]) && start_time<toepoch([2001 04 19 15 00 00])) || ...
					(  start_time>=toepoch([2001 04 20 03 00 00]) && start_time<toepoch([2001 04 23 15 00 00])) || ...
					(  start_time>=toepoch([2001 04 24 00 00 00]) && start_time<toepoch([2001 04 24 15 00 00])) )
				% The bias current is a bit too large
				% on p3 and p4 on C1&2 in April 2001.
				% Ignore p3, p4 and p34 and only use p1, p2 and p12.
				% Use only complete 3-hour intervals to keep it simple.
				probe_list = [1 2];
				irf_log('dsrc',sprintf('Too high bias current on p3&p4 sc%d',cl_id));
			end
		case 3
			if start_time>toepoch([2002 07 29 09 06 59])
				% p1 failure
				probe_list = 2:4;
				irf_log('dsrc',sprintf('p1 is BAD on sc%d',cl_id));
			end
    end
	pl = [12,34];
	switch cl_id
		case 1
			if start_time>toepoch([2009 10 14 07 00 00]) ||  ...
					(start_time>toepoch([2009 04 19 00 00 00]) && start_time<toepoch([2009 05 07 00 00 00]))
				pl = 32;
				irf_log('dsrc',sprintf('  !Only p32 exists on sc%d',cl_id));
			elseif (start_time>toepoch([2003 9 29 00 27 0]) || ...
					(start_time>toepoch([2003 3 27 03 50 0]) && start_time<toepoch([2003 3 28 04 55 0])) ||...
					(start_time>toepoch([2003 4 08 01 25 0]) && start_time<toepoch([2003 4 09 02 25 0])) ||...
					(start_time>toepoch([2003 5 25 15 25 0]) && start_time<toepoch([2003 6 08 22 10 0])) )
				pl = [32, 34];
				irf_log('dsrc',sprintf('  !Using p32 on sc%d',cl_id));
			elseif start_time>toepoch([2001 12 28 03 00 00])
				pl = 34;
				irf_log('dsrc',sprintf('  !Only p34 exists on sc%d',cl_id));
			elseif  (start_time>=toepoch([2001 04 12 03 00 00]) && start_time<toepoch([2001 04 12 06 00 00])) || ...
					(  start_time>=toepoch([2001 04 14 06 00 00]) && start_time<toepoch([2001 04 16 15 00 00])) || ...
				    (  start_time>=toepoch([2001 04 18 03 00 00]) && start_time<toepoch([2001 04 20 09 00 00])) || ...
					(  start_time>=toepoch([2001 04 21 21 00 00]) && start_time<toepoch([2001 04 22 03 00 00])) || ...
					(  start_time>=toepoch([2001 04 23 09 00 00]) && start_time<toepoch([2001 04 23 15 00 00]))
				% The bias current is a bit too large
				% on p3 and p4 on C1&2 in April 2001.
				% Ignore p3, p4 and p34 and only use p1, p2 and p12.
				% Use only complete 3-hour intervals to keep it simple.
				pl = 12;
				irf_log('dsrc',sprintf('  !Too high bias current on p34 for sc%d',cl_id));
			end
		case 2
			if start_time>toepoch([2007 11 24 15 40 0])
				pl = [32, 34];
				irf_log('dsrc',sprintf('  !Using p32 on sc%d',cl_id));
			elseif start_time>toepoch([2007 05 13 03 23 48])
				pl = 34;
				irf_log('dsrc',sprintf('  !Only p34 exists on sc%d',cl_id));
			elseif (start_time>=toepoch([2001 04 09 21 00 00]) && start_time<toepoch([2001 04 10 06 00 00])) || ...
					(  start_time>=toepoch([2001 04 10 09 00 00]) && start_time<toepoch([2001 04 19 15 00 00])) || ...
					(  start_time>=toepoch([2001 04 20 03 00 00]) && start_time<toepoch([2001 04 23 15 00 00])) || ...
					(  start_time>=toepoch([2001 04 24 00 00 00]) && start_time<toepoch([2001 04 24 15 00 00]))
				pl = 12;
				irf_log('dsrc',sprintf('  !Too high bias current on p34 for sc%d',cl_id));
			end
		case 3
			if start_time>toepoch([2003 9 29 00 27 0]) || ...
					(start_time>toepoch([2003 3 27 03 50 0]) && start_time<toepoch([2003 3 28 04 55 0])) ||...
					(start_time>toepoch([2003 4 08 01 25 0]) && start_time<toepoch([2003 4 09 02 25 0])) ||...
					(start_time>toepoch([2003 5 25 15 25 0]) && start_time<toepoch([2003 6 08 22 10 0])) 
				pl = [32, 34];
				irf_log('dsrc',sprintf('  !Using p32 on sc%d',cl_id));
			elseif start_time>toepoch([2002 07 29 09 06 59])
				pl = 34;
				irf_log('dsrc',sprintf('  !Only p34 exists on sc%d',cl_id));
			end
	end
%%%%%%%%%%%%%%%%%%%%%%% END PROBE MAGIC %%%%%%%%%%%%%%%%%%%%
probes=[];
%pl
filtv=zeros(1,4);   % remember V filter usage
    for out = 1:varsbsize;
        vt=varsb{out};
if 1
        vtlen=length(vt);
        field='E';

        if vt(1)=='B'
            probe=vt(3:4);
            sen = irf_ssub('p?',probe);
            filter='bp';
        elseif vt(1)=='S'
                field='dB';
                probe=lower(vt(3));
                sen=probe;
                filter='4kHz';
        elseif vt(1)=='V'
            filt=vt(vtlen);
            switch filt
                case 'U'
                    filter='32kHz';
                    filtv(1)=filtv(1)+1;
                case 'H'
                    filter='4kHz';
                    filtv(2)=filtv(2)+1;
                case 'M'
                    filter='180Hz';
                    filtv(3)=filtv(3)+1;
                case 'L'
                    filter='10Hz';
                    filtv(4)=filtv(4)+1;
                otherwise
                    error(['Unknown filter char for V: ' vt(vtlen)]);
            end
            if vtlen>3
                if vt(2)=='4'  % 43 check
                    probe = vt(3:-1:2);
                else
                    probe = vt(2:3);
                end
            else
                probe = vt(2);
            end
            sen = irf_ssub('p?',probe);
        end
        instrument = 'efw';

        [t,data] = caa_is_get(DBNO,st-B_DELTA,B_DT,cl_id,instrument,field,sen,filter,'burst','tm');
        start_satt = c_efw_burst_chkt(DBNO,filename);
        if isempty(start_satt)
            irf_log('dsrc','burst start time was not corrected')
        elseif isempty(t)
            irf_log('proc','t is empty. no iburst data?!');
            cd(old_pwd);
            return;
        else
            err_t = t(1) - start_satt;
            irf_log('dsrc',['burst start time was corrected by ' ...
            num2str(err_t) ' sec'])
            t = t - err_t;
        end
        d_phys=data*0.00212;
        data_phys = [t d_phys];

else
        if vars(out,4)==32
            filt=vars(out,3);
            if vars(out,3)==72 % H
                filter = '4kHz';
                if s==8 && out>4
                    probe = out-4;
                    sen = irf_ssub('p?',out-4);   
                else
                    probe = out;
                    sen = irf_ssub('p?',out);
                end
            elseif vars(out,3)==85 % U
                filter = '32kHz';
                probe = vars1(out,2);
                sen = irf_ssub('p?',probe);
            elseif vars(out,3)==77 % M
                filter = '180Hz';
                if s==8 && out>4
                    probe = out-4;
                    sen = irf_ssub('p?',out-4);
                else
                    probe = out;
                    sen = irf_ssub('p?',out);                    
                end
            elseif vars(out,3)==76 % L
                filter = '10Hz';
                if s==8 && out>4
                    probe = out-4;
                    sen = irf_ssub('p?',out-4);
                else
                    probe = out;
                    sen = irf_ssub('p?',out);
                end
            else            % BP12
                continue
            end
            
            field = 'E';
            instrument = 'efw';
            [t,data] = caa_is_get(DBNO,st-B_DELTA,B_DT,cl_id,instrument,field,sen,filter,'burst','tm');
            start_satt = c_efw_burst_chkt(DBNO,filename);
            if isempty(start_satt)
                irf_log('dsrc','burst start time was not corrected')
            elseif isempty(t)
                error('t is empty. bad channel? c4?');
            else
                err_t = t(1) - start_satt;
                irf_log('dsrc',['burst start time was corrected by ' ...
                num2str(err_t) ' sec'])
                t = t - err_t;
            end
            d_phys=data*0.00212;
            data_phys = [t d_phys];
            
        else
            filt=vars(out,4);
            if vars(out,4)==72
                filter = '8kHz';
                
                if strcmp(vars1(out,2:3),'43')
                    sen = irf_ssub('p?',34);
                    probe = 34;
                else
                    sen = irf_ssub('p?',vars1(out,2:3));
                    probe = 12;
                end
            elseif vars(out,4)==85
                filter = '32kHz';
                
                probe = out;
                if strcmp(vars1(out,2:3),'43')
                    sen = irf_ssub('p?',34);
                else
                    sen = irf_ssub('p?',vars1(out,2:3));
                end
            elseif vars(out,4)==77
                continue % What is this??? 77 never used???
                filter = '180Hz';
                
                probe = out;
                sen = irf_ssub('p?',vars1(out,2:3));
                if vars1(out,2:3)==43
                    sen = irf_ssub('p?',34)
                else
                    sen = irf_ssub('p?',vars1(out,2:3))
                end
            elseif vars(out,4)==76
            
                filter = '10Hz';
                
                probe = out;
            
                if vars1(out,2:3)==43
                    sen = irf_ssub('p?',34);
                else
                    sen = irf_ssub('p?',vars1(out,2:3));
                end
            else
                continue
            end
            
            field = 'E';
            instrument = 'efw';
            [t,data] = caa_is_get(DBNO,st-B_DELTA,B_DT,cl_id,instrument,field,sen,filter,'burst','tm');
            start_satt = c_efw_burst_chkt(DBNO,filename);
            if isempty(start_satt)
                irf_log('dsrc','burst start time was not corrected')
            else 
                err_t = t(1) - start_satt;
                irf_log('dsrc',['burst start time was corrected by ' ...
                num2str(err_t) ' sec'])
                t = t - err_t;
            end
            d_phys=data*0.00212;
            data_phys = [t d_phys];
            
        end
end
        if (out==1) % Create data matrix for t and all 8 possible variables
            if size(t,1)<3 || size(data,1)<3 % sanity check
                irf_log('proc','No usable burst data');               
                return;
            end
            dlen=size(data,1);
            data8=NaN(dlen,9);
            data8(:,1)=t;   % corrected time
        end
        data8(:,out+1)=data;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%    Saving the data to mEFWburstTM/mEFWburstR1    %%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        save_file = './mEFWburstTM.mat';
        if ~isempty(data)
            data = [t data];
            if vt(1)=='S'
                eval(irf_ssub(['tm?!b$=data;' 'save_list=[save_list ''tm?!b$ ''];'],filter,cl_id,probe)); 
            else    
                eval(irf_ssub(['tm?!p$=data;' 'save_list=[save_list ''tm?!p$ ''];'],filter,cl_id,probe)); 
            end
        else  
        end
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
            irf_log('save',[save_list ' -> ' save_file])   
            if exist(save_file,'file')
                eval(['save -append ' save_file ' ' save_list]);
            else 
                eval(['save ' save_file ' ' save_list]);
            end
        end
        % prepare the output
        if nargout > 0      
            if ~isempty(save_list)    
                sl = tokenize(save_list);  
                out_data = {sl};    
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end   
            end  
        else    
            clear out_data 
        end
    save_list='';

    if field=='E'
            data = data_phys;
    elseif field=='B'
         continue;
    elseif strcmp(field,'dB')
         continue;
    else
            disp(['Info: Unknown field ' field]);
    end     
        
        save_file = './mEFWburstR1.mat';
        data = data_phys;
        eval(irf_ssub(['PP?!p$=data;' 'save_list=[save_list ''PP?!p$ ''];'],filter,cl_id,probe));

        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
            irf_log('save',[save_list ' -> ' save_file])
            if exist(save_file,'file')
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
        end
        
        % prepare the output
         
        if nargout > 0 
            if ~isempty(save_list)
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end
            end
        else
            clear out_data
        end
        save_list='';
    end
    
data8(1:10,2:end)
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%    Getting normal data from ISDAT    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    st=data(1,1);
    sp=data(end,1);
    if st==-Inf || isnan(st)
        return;
    end
    if fetch_efw_data % must be 1 if no efw data in directory
        for v=1:length(vars0)
            data2 = getData(cdb,st-B_DELTA,B_DT,cl_id,vars0{v});
            if isempty(data2) && (strcmp(vars0{v},'tmode') || strcmp(vars0{v},'fdm'))
                irf_log('load','No EFW data')
                no_data = 1;
                break
            end
        end
    else
       data2 = getData(cdb,st-B_DELTA,B_DT,cl_id,'bfgm');
       data2 = getData(cdb,st-B_DELTA,B_DT,cl_id,'bsc');
    end
    clear data2;
    save_list='';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%    Getting magnetic burst data       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
if 0
B=[];
co = 'xyz';
    for comp=1:3
        [t,data] = caa_is_get(DBNO,st-B_DELTA,B_DT,cl_id,'efw','dB',co(comp),'4kHz','burst','tm');
        
        if isempty(t) || isempty(data)
            irf_log('dsrc',irf_ssub('No data for wBSC4kHz?',cl_id))
            out_data = []; continue
        else
            B(:,comp) = data; %#ok<AGROW>
        end   
       
       
    end
    if ~isempty(B)
        B = -B/7000; % Convert to V - same as STAFF B_SC_Level_1
    
    % Correct start time of the burst
        start_satt = c_efw_burst_chkt(DBNO,filename);
        if isempty(start_satt)
        irf_log('dsrc','burst start time was not corrected')
        else 
            err_t = t(1) - start_satt;
            irf_log('dsrc',['burst start time was corrected by ' ...
            num2str(err_t) ' sec'])
            t = t - err_t;
        end
        B=[t B];
        B = rm_ib_spike(B);
        size(B)

        save_file = './mBSCBurst.mat';
        %eval(irf_ssub(['diE?p1234=B;' 'save_list=[save_list ''diE?p1234 ''];'],cl_id));
        eval(irf_ssub(['w4kHz?=B;' 'save_list=[save_list ''w4kHz? ''];'],cl_id));
              
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
            irf_log('save',[save_list ' -> ' save_file])
            if exist(save_file,'file')    
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
        end
        % prepare the output
        if nargout > 0 
            if ~isempty(save_list) 
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end
            end
        else
            clear out_data
        end
        save_list='';
       
   [B] = irf_filt(B,10,0,[],3);
filt
if 0
        switch filt
            case 72
                filt='H';
            case 76
                filt='L';
            otherwise
                filt='H';
        end
end
        B = c_efw_invert_tf(B,filt);
        B = c_efw_burst_bsc_tf(B,cl_id); % Apply the transfer function

        save_file = './mBSCBurst.mat';
        %eval(irf_ssub(['diE?p1234=B;' 'save_list=[save_list ''diE?p1234 ''];'],cl_id));
        eval(irf_ssub(['wBSC4kHz?=B;' 'save_list=[save_list ''wBSC4kHz? ''];'],cl_id));
              
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
            irf_log('save',[save_list ' -> ' save_file])
            if exist(save_file,'file')    
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
        end
        % prepare the output
        if nargout > 0 
            if ~isempty(save_list) 
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end
            end
        else
            clear out_data B
        end
        save_list='';
        
    
    else
            
    end 
end
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%    Checking the order of the data    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    
[ok,pha] = c_load('Atwo?',cl_id);

test = load('mEFWburstTM.mat');
%load('mEFWburstTM.mat')
%load('mER.mat')
fn = fieldnames(test);
bla=char(fn);
cc=size(bla);
test2 = load('mEFWburstR1.mat');
%load('mEFWburstR1.mat')
load('mER.mat')
fn2 = fieldnames(test2);
bla2=char(fn2);
cc2=size(bla2);
ff=0;

if cc2(1)>=4
    if exist(irf_ssub('wE?p!',cl_id,12))~=0
%        name11 = irf_ssub('PP?!p$',filter,cl_id,1);
%        name22 = irf_ssub('PP?!p$',filter,cl_id,2);
        tt1=eval(irf_ssub('wE?p!',cl_id,12));   %(t1(:,2)-t2(:,2))/88;
        probev=1;
    elseif exist(irf_ssub('wE?p!',cl_id,34))~=0
%        name11 = irf_ssub('PP?!p$',filter,cl_id,3);
%        name22 = irf_ssub('PP?!p$',filter,cl_id,4);
        tt1=eval(irf_ssub('wE?p!',cl_id,34));   %(t1(:,2)-t2(:,2))/88;
        probev=3;
    else
        tt1=eval(irf_ssub('wE?p!',cl_id,32));   %(t1(:,2)-t2(:,2))/88;
        probev=2;
    end
    
if 1      % ff gg di
 bestguess=[-1 -1 -1];
 for di=1:2:varsbsize
    t1(:,1:2)=data8(:,[1 di+1]);
    t1m=mean(t1(:,2));
    t2(:,1:2)=data8(:,[1 di+2]);
    t2m=mean(t2(:,2));
di
    divf=t2m/t1m;
%    if divf<0.67 || divf>1.5    % different data types skip
    if divf<0.5 || divf>2    % different data types skip
divf
        continue;
    end
    aa1=c_phase(tt1(:,1),pha);
    if isempty(aa1)
        continue;
    end
    sp1=c_efw_sfit(12,3,10,20,tt1(:,1),tt1(:,2),aa1(:,1),aa1(:,2),1,output(1,1)); % org sfit2
    distance=88;
    tt2=(t1(:,2)-t2(:,2))/distance;
    aa2=c_phase(t2(:,1),pha);
    if isempty(aa2)
        continue;
    end
    sp2=c_efw_sfit(12,3,10,20,t2(:,1),tt2,aa2(:,1),aa2(:,2),1,output(1,1));       % org sfit2
    [a,b] = size(sp2);
    gg=0;                
    i=1;

    while i<a+1
        [c,d]=find(sp1==sp2(i,1));
        ex1=sp1(c,2);
        ex2=sp2(i,2);
        ey1=sp1(c,3);
        ey2=sp2(i,3);
                                
        timevec=fromepoch(sp2(i,1));
        z1=atan2(ey1,ex1);
        z2=atan2(ey2,ex2);
        y=round(abs(((z1-z2)/pi)*180));
                      
        if ~isempty(y)
            if isnan(y)==1 
%                irf_log('proc','NaN');
            elseif  25<y && y<155
                gg=gg+1;
            elseif  205<y && y<335 
                gg=gg+1;
            else
                ff=ff+1;
%                irf_log('proc','the data match');
            end
        end

        i=i+1;

    end
%t1(1:5,2)
%t2(1:5,2)
ff
gg
    if (ff-gg>bestguess(1)-bestguess(2)) || (ff-gg==bestguess(1)-bestguess(2) && gg<bestguess(2))
        bestguess=[ff gg di];
    end
end
bestguess
xy=1:varsbsize;
svar=irf_ssub('V?',probev);
svar1=irf_ssub('V?',probev+1);
pfound=false;
% find variable position
for pos=1:varsbsize-1
    if strcmp(varsb{pos}(1:2),svar) && length(varsb{pos})==3 && strcmp(varsb{pos+1}(1:2),svar1) && length(varsb{pos+1})==3
        pfound=true;
        break;
    end
end
%size(data8)
data8ord=data8; % assume no order change
%bestguess(3)=3;
pos
if ~pfound || bestguess(1)==-1
    irf_log('proc','Can not find burst order. standard order 1-n used');
elseif pos~=bestguess(3)
    % make order vector
    pcnt=pos;
    for j=bestguess(3):varsbsize
        xy(j)=pcnt;
        pcnt=pcnt+1;
        if pcnt>varsbsize
            pcnt=1;
        end
    end
    if bestguess(3)>1
        pcnt=pos-1;
        for j=bestguess(3)-1:-1:1
            if pcnt<1
                pcnt=varsbsize;
            end
            xy(j)=pcnt;
            pcnt=pcnt-1;
        end
    end
    % order data
    for j=1:varsbsize
        data8ord(:,xy(j)+1)=data8(:,j+1);
    end
%    data8(1:5,2:end)
end

%data8ord(1:5,2:end)
xy
probe_list
else
    t1=eval(name11); %name11 = irf_ssub('tm?!p$',filter,cl_id,bla(iii,1)); %irf_ssub('SSS2.wE?p!',cl_id,probe(iii,1));                    
    t2=eval(name22); %name22 = irf_ssub('tm?!p$',filter,cl_id,bla(iii,2));

    aa1=c_phase(tt1(:,1),pha);           
    sp1=c_efw_sfit(12,3,10,20,tt1(:,1),tt1(:,2),aa1(:,1),aa1(:,2),1,output(1,1)); % org sfit2
    distance=88;
    tt2=(t1(:,2)-t2(:,2))/distance;
    aa2=c_phase(t2(:,1),pha);        
    sp2=c_efw_sfit(12,3,10,20,t2(:,1),tt2,aa2(:,1),aa2(:,2),1,output(1,1));       % org sfit2
    [a,b] = size(sp2);
    gg=0;                
    i=1;

    while i<a+1
        [c,d]=find(sp1==sp2(i,1));
        ex1=sp1(c,2);
        ex2=sp2(i,2);
        ey1=sp1(c,3);
        ey2=sp2(i,3);
                                
        timevec=fromepoch(sp2(i,1));
        z1=atan2(ey1,ex1);
        z2=atan2(ey2,ex2);
        y=round(abs(((z1-z2)/pi)*180));
                      
        if ~isempty(y)
            if isnan(y)==1 
                irf_log('proc','NaN');
            elseif  25<y && y<155
                gg=gg+1;
            elseif  205<y && y<335 
                gg=gg+1;
            else
                ff=ff+1;
%                irf_log('proc','the data match');
            end
        end
        
        i=i+1;
                            
    end

    if ff>gg
        xy=[1 2 3 4];
    else
        xy=[3 4 1 2];
    end

end    
    probe_l=probe_list;
                    
else
    data8ord=data8; % assume no order change
    probe_l=1:length(pl);
    if length(pl)==2
        xy=[1 2];
    else
        if pl==34
            xy=[1];
        else
            xy=[2];
        end
    end
end
save_time=[];

if 1
    % save raw ordered data
    save_file = './mEFWburstTM1.mat';
    save_list='';
    burst_info=sprintf('%s ',varsb{:});
    eval(irf_ssub(['ib?_info=burst_info(1:end-1);' 'save_list=[save_list ''ib?_info ''];'],cl_id));

    eval(irf_ssub(['iburst?=data8ord;' 'save_list=[save_list ''iburst? ''];'],cl_id));
    if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
        irf_log('save',[save_list ' -> ' save_file])
        if exist(save_file,'file')
            eval(['save -append ' save_file ' ' save_list]);
        else
            eval(['save ' save_file ' ' save_list]);
        end
    end
    % filter data
    % calib data
    data8ordfc=zeros(size(data8ord));
    data8ordfc(:,1)=data8ord(:,1);
    if varsbsize>4
        Stemp=zeros(size(data8ord,1),4);
        Stemp(:,1)=data8ord(:,1);
        Smem=Stemp;
    end
    Spos=zeros(1,3);
    Scnt=1;
    t=data8ord(:,1);
    ixm=zeros(3,size(data8ord,1))>0;
    for i=1:varsbsize
        if varsb{i}(1)=='B'
            [sfilt ix]=rm_spike_ndt([t data8ord(:,i+1)],filt);
            sfilt(ix,2)=nan;
            data8ordfc(:,i+1)=sfilt(:,2); % factor?            
        elseif varsb{i}(1)=='S'
            Spos(Scnt)=i;
            xyzord=double(varsb{i}(3))-87;
            Scnt=Scnt+1;
            [scfilt ix]=rm_spike_ndt([t data8ord(:,i+1)],filt);
            ixm(xyzord,:)=ix;
            scfilt(:,2)=-scfilt(:,2)/7000;
%            data8ord(:,i+1)=scfilt(:,2);
            Stemp(:,xyzord+1)=scfilt(:,2);
            Smem(:,xyzord+1)=scfilt(:,2);
        elseif varsb{i}(1)=='V'
            [spfilt ix]=rm_spike_ndt([t data8ord(:,i+1)],filt);
            spfilt(:,2)=spfilt(:,2)*0.00212;
            spfilt=c_efw_invert_tf(spfilt,filt);
            spfilt(ix,2)=nan; % insert nan on bad data
            data8ordfc(:,i+1)=spfilt(:,2);
        else
            error(['Unknown ib data type: ' varsb{i}]);
        end
    end

    if Spos(end)  % filter SCX-Z
        save_file = './mBSCBurst.mat';
        save_list='';
        [B] = irf_filt(Stemp,10,0,[],3);
        f=filt;
        if f~='L'
            f='H';
        end
        B = c_efw_invert_tf(B,f);
        size(B)
        B = c_efw_burst_bsc_tf(B,cl_id); % Apply the transfer function
        for i=1:3 % insert nan on bad data
            B(ixm(i,:),i+1)=nan;
        end
        eval(irf_ssub(['w4kHz?=Smem;' 'save_list=[save_list ''w4kHz? ''];'],cl_id));
        eval(irf_ssub(['wBSC4kHz?=B;' 'save_list=[save_list ''wBSC4kHz? ''];'],cl_id));
    
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
            irf_log('save',[save_list ' -> ' save_file])
            if exist(save_file,'file')    
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
        end
    elseif varsbsize<=4
        irf_log('proc','No ib SCX-Z data <=4 cols');
    else
        irf_log('proc','No ib SCX-Z data >4 cols');
    end
    save_file = './mEFWburstR.mat';
    save_list='';
    t=data8ordfc(:,1);
    for i=1:varsbsize
        if varsb{i}~='V'
            continue
        end

        data=[t data8ordfc(:,i+1)];
        probe=varsb{i}(2);
        if length(varsb{i})>3
            if vt(2)=='4'  % 43 check
                probe = vt(3:-1:2);
            else
                probe = vt(2:3);
            end
%varsb{i}
        else
            probe=varsb{i}(2);
        end
        filter=get_filter(varsb{i});
%        eval(irf_ssub(['wbE?p!=data;' 'save_list=[save_list ''wbE?p! ''];'],cl_id,probe)); 
        eval(irf_ssub(['P?!p$=data;' 'save_list=[save_list ''P?!p$ ''];'],filter,cl_id,probe));
    end
    if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
        irf_log('save',[save_list ' -> ' save_file])

        if exist(save_file,'file')
            eval(['save -append ' save_file ' ' save_list]);
        else
            eval(['save ' save_file ' ' save_list]);
        end
    end
    % make L2
    getData(cp,cl_id,'whip');
%    getData(cp,cl_id,'p');%
%    getData(cp,cl_id,'die');%
    getData(cp,cl_id,'pburst');
    getData(cp,cl_id,'dieburst');
    getData(cp,cl_id,'dibscburst');

    if burst_plot
        clf;
%st=st+300
%sp=sp+300
        dt2=5;
        st_int=st-dt2;
        st_int2=sp-st+2*dt2;
        %summaryPlot(cp,cl_id,'fullb','ib','st',st_int,'dt',st_int2,'vars',vars1);
%        summaryPlot(cp,cl_id,'fullb','ib','st',st_int,'dt',st_int2,'vars',char(varsb));
        summaryPlot(cp,cl_id,'fullb','ib','st',st_int,'dt',st_int2,'vars',char([fnshort varsb]));
        %summaryPlot(cp,cl_id,'ib','st',st_int,'dt',st_int2);
        if plot_save
            orient landscape
            print('-dpdf', fname);
        end
    end

    ret=0;
    delete('mEFWburstR1.mat'); %Remove some files
    delete('mEFWburstTM.mat');
    cd(old_pwd);
else
for aa=probe_l
    save_list='';
    aa
    save_file = './mEFWburstR11.mat';
        name1 = bla2(xy(aa),:);
        data = eval(name1);
        name = bla2(aa,:);
        if vars(aa,4)>60
            eval(irf_ssub(['wb1E?p!=data;' 'save_list=[save_list ''wb1E?p! ''];'],cl_id,name(9:end))); 
        else
            
            eval(irf_ssub(['P1?!p$=data;' 'save_list=[save_list ''P1?!p$ ''];'],filter,cl_id,aa));
        end
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
	
            irf_log('save',[save_list ' -> ' save_file])
	
            if exist(save_file,'file')
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
            
        end
        
        % prepare the output
  
        if nargout > 0 
	    
            if ~isempty(save_list)
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end   
            end  
            
        else   
            clear out_data
        end
        
        save_list='';
    
    save_file = './mEFWburstTM1.mat';
%        name = bla(xy(aa),:)
%        data = eval(name);
        name = bla(aa,:);
        data = eval(name);
        if (aa==1)
            burst_info=sprintf('%s,',varsb{:})
            eval(irf_ssub(['ib?_info=burst_info(1:end-1);' 'save_list=[save_list ''ib?_info ''];'],cl_id));
        end
name
char(vars(aa,:))
        if vars(aa,4)>60
            eval(irf_ssub(['wb1E?p!=data;' 'save_list=[save_list ''wb1E?p! ''];'],cl_id,name(9:end))); 
        else
            eval(irf_ssub(['tm1?!p$=data;' 'save_list=[save_list ''tm1?!p$ ''];'],filter,cl_id,aa));
        end
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
	
            irf_log('save',[save_list ' -> ' save_file])
	
            if exist(save_file,'file')
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
            
        end
        
        % prepare the output
  
        if nargout > 0 
	    
            if ~isempty(save_list)
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end   
            end  
            
        else   
            clear out_data
        end
end
end

return % !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%    Removing spikes from the data                 %%%%%%%%%%%%%%%%%%%%%
%%%%%                                                  %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
t3 = load('mEFWburstR11.mat');
%load('mEFWburstR11.mat')
fn3 = fieldnames(t3);
bla3=char(fn3);
cc3=size(bla3);
sdevthold=4;

for aa=1:cc3(1)
    if vars(aa,4)>60
            name = irf_ssub('wb1E?p!',cl_id,bla3(aa,7:end));
    else
            name = irf_ssub('P1?!p$',filter,cl_id,bla3(aa,end));
    end
    
    if  vars(aa,4)>60 && (name(9:end)==12 || name(9:end)==34)
        e=eval(name);
    else
        
if 0        % no filter       
        e=eval(name);
elseif 1    % non destructive time filter
        e=eval(name);
        ix=e(:,1)<0;
        standard=std(e);

        x=1;  
        y=2;
        xx=0;
        while abs(e(y,2)-e(x,2))<3*standard(1,2) && y<length(e)     
            x=x+1;
            y=y+1;
            xx=xx+1;
        end
                           
        i=1;    
        x=x-xx;                   
        z=x+5;

        if z<length(e)                     
%            e(x:z,:)=[];
            if x==1
                meanv=e(z+1,2);
            else
                meanv=(e(x-1,2)+e(z+1,2))/2;
            end
            e(x:z,2)=meanv;
            ix(x:z)=true;
%            e(x:z,2)=0;                 
            while i<round(length(e)/8192)
                x=x+8192-5;                    
                z=z+8192-5;                    
%                e(x:z,:)=[];
                meanv=(e(x-1,2)+e(z+1,2))/2;
                e(x:z,2)=meanv;
                ix(x:z)=true;
                i=i+1;                 
            end
        end

        elen=size(e,1);
        step=round(elen/97)    % step size
        for i=1:step:elen-1
            stop=i+step-1;
            if stop>elen-1
                stop=elen-1;
            end
            if (i>1)
                te=e(i-1:stop,2);   % 1 point overlap
            else
                te=e(i:stop,2);
            end
            sdev=std(te);
            meanv=mean(te);
            out=abs(te-meanv)>sdevthold*sdev;
            outlen=length(out);
            % put linear value on spike
            x=2;
            while (x < outlen)
                if out(x)                
                    s=x+1;
                    while (s < outlen-1)
                        if ~out(s)
                            s=s-1;
                            break;
                        end
                        s=s+1;
                    end
                    if s>=outlen
                        s=outlen-1;
                    end
                    xx=i+x-2;
                    ss=i+s-2;
%sdev
%meanv
%e(xx-1:ss+1,2)
                    if x==s
                        e(xx:ss,2)=(e(xx-1,2)+e(ss+1,2))/2;
                    else
                        df=e(ss+1,2)-e(xx-1,2);
                        inc=df/(ss-xx+2);
                        for ii=0:ss-xx
                            e(xx+ii,2)=(ii+1)*inc+e(xx-1,2);
                        end
                    end
                    ix(xx:ss)=true;
                    x=s;
%e(xx-1:ss+1,2)
                end
                x=x+1;
            end

        end
sum(ix)
else
        data_phys=eval(name);
        standard=std(eval(name));   
    
        x=1;  
        y=2;
        xx=0;
            
        while abs(data_phys(y,2)-data_phys(x,2))<3*standard(1,2) && y<length(data_phys)     
            x=x+1;
            y=y+1;
            xx=xx+1;
        end
        
        a=data_phys;                   
        i=1;    
        x=x-xx;                   
        z=x+5;

        if z<length(a)                     
            a(x:z,:)=[];                 
%            a(x:z,2)=0;                 
            while i<round(length(data_phys)/8192)                        
                x=x+8192-5;                    
                z=z+8192-5;                    
                a(x:z,:)=[];
%                meanv=(a(x-1,2)+a(z+1,2))/2;
%                a(x:z,2)=meanv;
                i=i+1;                 
            end

            pl=length(a);
            x=round(pl/50)
            i=1;                   
            k=1;                   
            d=x;                    
            e=a;                    
            f=1;                    
            g=0;                    
               
            while i<(length(a)/x)+1
                if d>pl
                    d=pl;
                end

                count=a(k:d,:);
                mu = mean(count);
                sigma = std(count);
                [n,p] = size(count);
                    
                % Create a matrix of mean values by                    
                % replicating the mu vector for n rows                   
                MeanMat = repmat(mu,n,1);
                    
                % Create a matrix of standard deviation values by                    
                % replicating the sigma vector for n rows                     
                SigmaMat = repmat(sigma,n,1);                  
                    
                % Create a matrix of zeros and ones, where ones indicate                   
                % the location of outliers                   
                outliers = abs(count - MeanMat) > 2*SigmaMat;                   

                % Calculate the number of outliers in each column                     
%                nout = sum(outliers);                   
                count(any(outliers,2),:) = [];
%                count(any(outliers,2),2) = 0;
                [h,j]=size(count);                    
                g=g+h;                  
                e(f:g,:)=count;                   
                f=f+h;                    
                k=k+x;                   
                d=d+x;                   
                i=i+1;
              
            end
            if g<d
                e(g:end,:)=[];
%                e(g:end,2)=0;
            else
            end
             
        else
            
        end

        if isempty(save_time)==1
%            irf_log('proc','save_time empty');
            save_time=e;
        else
            a=length(e);
            b=length(save_time);
            
%            irf_log('proc',['save_time ' num2str(a) ' ' num2str(b)]);
            if a>b
                x=a-b;
                e(b+1:b+x,:)=[];
%                e(b+1:b+x,2)=0;
            elseif a<b
                x=b-a;
                e(a+1:a+x,:)=e(a-x+1:a,:);
                
            else
            end
        end

    end
end    
    switch filt
        case 72
            filt='H';
        case 76
            filt='L';
        otherwise
            filt='U';
    end
% NaNs cant be used in FFT.
    e = c_efw_invert_tf(e,filt);
% Insert NaN
    if exist('ix','var')
        e(ix,2)=nan;
    end

    
    save_file = './mEFWburstR.mat';
 save_list='';
   
    data=e;
data(1:15,2:end)
    if vars(aa,4)>60
        eval(irf_ssub(['wbE?p!=data;' 'save_list=[save_list ''wbE?p! ''];'],cl_id,name(7:end))); 
    else
        eval(irf_ssub(['P?!p$=data;' 'save_list=[save_list ''P?!p$ ''];'],filter,cl_id,name(end)));
    end
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
            irf_log('save',[save_list ' -> ' save_file])
	
            if exist(save_file,'file')
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
        end
        
        % prepare the output
  
        if nargout > 0 
            if ~isempty(save_list)
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end   
            end  
        else   
            clear out_data
        end
       save_list='';
       
end

% Create mEFWburst mBSC...
for v=length(vars11)-4:length(vars11)
%    vars11{v}
    getData(cp,cl_id,vars11{v});
end

if burst_plot
%for v=1:length(vars11)-5
%    getData(cp,cl_id,vars11{v});	
%end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%    Making summary plots of the data  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%                                      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clf;

dt2=5;
st_int=st-dt2;
st_int2=sp-st+2*dt2;
orient tall
%summaryPlot(cp,cl_id,'fullb','ib','st',st_int,'dt',st_int2,'vars',vars1);
summaryPlot(cp,cl_id,'fullb','ib','st',st_int,'dt',st_int2);
if plot_save
    print('-dpng', fname);
end

if cord_plot
load('mR.mat');
cordinates=eval(irf_ssub(['R?'],cl_id));
YZ=sqrt(cordinates(1,3)^2+cordinates(1,4));
GSE(cord,:)=[cordinates(2,:) YZ];
GSM(cord,:)=irf_gse2gsm(cordinates(2,:));
cord=cord+1;
    %catch
    %end

%end
  if ~isempty(GSE)
    orient PORTRAIT
    GSM(:,2:4)=GSM(:,2:4)/6171;
    GSE(:,2:5)=GSE(:,2:5)/6371;
    figure
    subplot(2,1,1);plot(GSE(:,2),GSE(:,5),'x')
    title('Positions of bursts in GSE')
    xlabel('X [Re]')
    ylabel('sqrt(Y^2 + Z^2) [Re]')
    grid on
    subplot(2,1,2);plot(GSM(:,2),GSM(:,4),'x')
    title('Positions of bursts in GSM')
    xlabel('X [Re]')
    ylabel('Z [Re]')
    grid on

        save_file = './position.mat';
        
        data = GSM;
                
        eval(irf_ssub(['GSM=data;' 'save_list=[save_list ''GSM ''];'],1));
              
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
                     
            irf_log('save',[save_list ' -> ' save_file])
	        
            if exist(save_file,'file')
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
            
        end
        
        % prepare the output
        if nargout > 0 
	            
            if ~isempty(save_list)
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end
            end
        else
            clear out_data
        end
        
        save_list='';
        
%        save_file = './position.mat';
        
        data = GSE;
                
        eval(irf_ssub(['GSE=data;' 'save_list=[save_list ''GSE ''];'],1));
              
        if flag_save==1 && ~isempty(save_list) && ~isempty(save_file)
            irf_log('save',[save_list ' -> ' save_file])
            if exist(save_file,'file')
                eval(['save -append ' save_file ' ' save_list]);
            else
                eval(['save ' save_file ' ' save_list]);
            end
            
        end
        
        % prepare the output
        if nargout > 0 
            if ~isempty(save_list)
                sl = tokenize(save_list);
                out_data = {sl};
                for i=1:length(sl)
                    eval(['out_data{i+1}=' sl{i} ';'])
                end
            end
        else
            clear out_data
        end
        
        save_list='';

  end
end
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dataout = rm_ib_spike(magneticdata)
% Remove spikes in staff IB data

DT = 0.455; % sec, time window
THR = 5; % data above TRH StDev discarded

dataout = magneticdata;

ndata = length(magneticdata(:,1));
dt2 = ceil(DT*c_efw_fsample(magneticdata,'ib')/2);

i = 1;
while i < ndata
    i2 = i + dt2*2;
    if i2 > ndata % last window
        i = ndata - dt2*2;
        i2 = ndata;
    end
    x = magneticdata(i:i2,2:4);
    y = x;
    iii=length(y);
    x = detrend(x);
    s = std(x);
    for comp=3:-1:1
        if s(comp)<1e-6
            continue;
        end
        ii = find(abs(x(:,comp))>THR*s(comp));
        if ~isempty(ii)
            if ii(end)==iii
                y(ii,:) = y(ii-1,:);
            else
                y(ii,:) = y(ii+1,:);
            end
        end
    end
    
    dataout(i:i2,2:4) = y;
    
    i = i2 + 1;
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [rdata ix] = rm_spike_ndt(e,filt,typesc)
% Remove spikes in data non destructive for time
% e:      [time data]
% filter: U L H M
% typesc: 0=V?? 1=SCX-Z

ix=e(:,1)<0;

PL = 8192; % page length
PI = 2; % Number of pages after which we have to shift the mask right by 1 point
        % Every PI*4 pages we have to extend the mask by two more points
NP = ceil(length(e)/PL); % number of pages
if NP < 12, PL = PL/2; NP = NP*2; PI = PI*2; end
rdata=e;
mask = [-1 0 1 2 3 4];
m = [];
for i=1:NP
    if floor((i-1)/PI)==(i-1)/PI
        % Shift the mask every PI pages
        mask = mask + 1;
    end
    if floor((i-1)/(PI*4))==(i-1)/(PI*4)
        % Extend the mask every PI*4 pages
        mask = [mask mask(end)+[1 2]]; %#ok<AGROW>
    end
    pos=(i-1)*PL+mask;
    if pos(1)<1
rdata(pos(3):pos(end)+1,2)
        rdata(pos(3:end),2)=rdata(pos(end)+1,2);
rdata(pos(3):pos(end)+1,2)
        ix(pos(3:end))=true;
    else
rdata(pos(1)-1:pos(end)+1,2)
        rdata(pos,2)=(rdata(pos(1)-1,2)+rdata(pos(end)+1,2))/2;
rdata(pos(1)-1:pos(end)+1,2)
        ix(pos)=true;
    end
    m = [m pos]; %#ok<AGROW>
end

%m( m<=0 ) = []; % Remove the first points containing -1, 0
size(ix)

%rdata(m,2:end) = NaN;

end

function filt = get_filter(ibstr)
% get filter from ib string

    if ibstr(1)=='B'
        filt='bp';
    elseif ibstr(1)=='S'
            filt='4kHz';
    elseif ibstr(1)=='V'
        switch ibstr(end)
            case 'U'
                filt='32kHz';
            case 'H'
                filt='4kHz';
            case 'M'
                filt='180Hz';
            case 'L'
                filt='10Hz';
            otherwise
                error(['Unknown filter char for V: ' ibstr(end)]);
        end
    end
end