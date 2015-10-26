function mms_sdc_sdp_proc2( procName, varargin)
% MMS_SDC_SDP_PROC2 NEW startup function for MMS processing. Rely on DEFATT
% files for phase calculations, if they are present in the DATA_PATH_ROOT
% instead of hk 101 sunpulses.
%
% 	See also MMS_SDC_SDP_INIT, MMS_SDP_DMGR.

% Store runTime when script was called. To ease for SDC, create an empty
% file with name being the same as output file created and suffix
% _runTime.txt placed in "($LOG_PATH_ROOT)/mmsX/edp/"
runTime = datestr(now,'yyyymmddHHMMSS'); 

global ENVIR MMS_CONST;

% Setup irfu-matlab
init_matlab_path()

% Load global contants.
if isempty(MMS_CONST), MMS_CONST = mms_constants(); end

HK_101_File = ''; % HK with sunpulse, etc.
HK_105_File = ''; % HK with sweep status etc.
HK_10E_File = ''; % HK with bias guard settings etc.
ACE_File = '';
DCV_File = '';
DCE_File = '';
L2A_File = ''; % L2A file, contain offsets from fast/slow to be used by brst and for L2Pre process.
DEFATT_File = ''; % Defatt file used for l2pre or reprocessing of QL.
HdrInfo = [];

parse_input(procName, varargin{:});

% All input arguments read. All files required identified correct?
% QL, SCPOT req: hk101 or DEFATT, hk10e, hk105, dce and possibly dcv (if not incl. in dce).
if any([(isempty(HK_101_File) && isempty(DEFATT_File)), isempty(DCE_File),...
    isempty(HK_105_File), isempty(HK_10E_File)])
  irf.log('warning', 'MMS_SDC_SDP_PROC missing some input.');
  for i=1:nargin-1
    irf.log('warning',['Received input argument: ', varargin{i}]);
  end
elseif(isempty(DCV_File) && procId~=MMS_CONST.SDCProc.l2pre )
  irf.log('debug','It appears we are running with the dcv data combined into dce file.');
end

%% Processing for SCPOT, QL or other products.
% Load and process identified files in the following order first any of the
% available files out of "DCE", "HK_10E", "HK_101", "HK_105", then lastly
% the "DCV".
% Reason: DCV in data manager calls on other subfunctions which may require
% DCE, HK_101, HK_105 and HK_10E files to already be loaded into memory.

switch procId
  case {MMS_CONST.SDCProc.scpot, MMS_CONST.SDCProc.ql, MMS_CONST.SDCProc.l2a}
    if(~isempty(HK_10E_File))
      fileSplit = strsplit(HK_10E_File,':');
      for iFile=1:size(fileSplit,2)
        irf.log('notice', [procName ' proc using: ' fileSplit{iFile}]);
        src_fileData = load_file(fileSplit{iFile},'hk_10e');
        update_header(src_fileData); % Update header with file info.
      end
    end
    if(~isempty(HK_105_File))
      fileSplit = strsplit(HK_105_File,':');
      for iFile=1:size(fileSplit,2)
        irf.log('notice', [procName ' proc using: ' fileSplit{iFile}]);
        src_fileData = load_file(fileSplit{iFile},'hk_105');
        update_header(src_fileData); % Update header with file info.
      end
    end
    %% Phase information, somewhat special case.
    if(~isempty(DEFATT_File))
      % Defatt was sent as argument, use these
      fileSplit = strsplit(DEFATT_File,':');
      for iFile=1:size(fileSplit,2)
        irf.log('notice', [procName ' proc using: ' fileSplit{iFile}]);
        [dataTmp,src_fileData] = mms_load_ancillary(fileSplit{iFile},'defatt');
        Dmgr.set_param('defatt', dataTmp);
        update_header(src_fileData); % Update header with file info.
      end
      % Process DCE file as well.
      if isempty(DCE_File)
        errStr = ['missing required input for ' procName ': DCE_File'];
        irf.log('critical',errStr);
        error('Matlab:MMS_SDC_SDP_PROC:Input', errStr);
      end
      irf.log('notice', [procName ' proc using: ' DCE_File]);
      src_fileData = load_file(DCE_File,'dce');
      update_header(src_fileData) % Update header with file info.
    else
      % NO defatt as argument. Begin by loading the DCE to get information
      % about which times we process. Then go looking for DEFATT matching
      % this time. If DEFATT is then found, use this, else use the less
      % acurate HK 101 sunpulses sent as argument for phase computation.
      if isempty(DCE_File)
        errStr = ['missing required input for ' procName ': DCE_File'];
        irf.log('critical',errStr);  error(errStr);
      end
      irf.log('notice', [procName ' proc using: ' DCE_File]);
      dce_obj = dataobj(DCE_File);
      [~,tmpName, ~] = fileparts(DCE_File);
      update_header(mms_fields_file_info(tmpName)); % Update header with file info.
      tint = EpochTT(sort(dce_obj.data.Epoch.data));
      % Keep only valid times (well after end of mission).
      tint(tint.tlim(irf.tint('2015-01-01T00:00:00.000000000Z/2040-12-31T23:59:59.999999999Z')));
      % Create a time interval for start and stop of dce epoch times.
      tint = irf.tint(tint.start, tint.stop);
      % Go looking for DEFATT to match tint.
      mms.db_init('local_file_db', ENVIR.DATA_PATH_ROOT); % Setup mms database
      list = mms.db_list_files(['mms',HdrInfo.scIdStr,'_ancillary_defatt'],tint);
      if(isempty(list) || list(1).start >= tint.start || list(end).stop <= tint.stop)
        % If no DEFATT was found or it did not cover all of tint, use HK 101 files.
        if(~isempty(HK_101_File))
          fileSplit = strsplit(HK_101_File,':');
          for iFile=1:size(fileSplit,2)
            irf.log('notice', [procName ' proc using: ' fileSplit{iFile}]);
            src_fileData = load_file(fileSplit{iFile},'hk_101');
            update_header(src_fileData) % Update header with file info.
          end
        else
          % Should not be here!
          errStr = 'No DEFATT was found and no HK 101 identified in arguments.';
          irf.log('critical',errStr); error(errStr);
        end
      end
      for ii=1:length(list)
        irf.log('notice', [procName ' proc using: ',list(ii).name]);
        [dataTmp, src_fileData] = mms_load_ancillary([list(ii).path, filesep, ...
          list(ii).name], 'defatt');
        Dmgr.set_param('defatt', dataTmp);
        update_header(src_fileData); % Update header with file info.
      end
      %% Second special case, brst QL (use L2A from previously processed Fast).
      if(regexpi(DCE_File,'_brst_') && procId==MMS_CONST.SDCProc.ql)
        if(~isempty(L2A_File))
          irf.log('notice', [procName ' proc using: ' L2A_File]);
          src_fileData = load_file(L2A_File,'l2a');
          update_header(src_fileData); % Update header with file info.
        else
          irf.log('warning',[procName ' but no L2A file from Fast Q/L.']);
        end
      end
      % Go on with DCE (already read).
      Dmgr.set_param('dce',dce_obj);
    end

    if ~isempty(DCV_File)
      % Separate DCV file (during commissioning)
      irf.log('notice', [procName ' proc using: ' DCV_File]);
      src_fileData = load_file(DCV_File,'dcv');
      update_header(src_fileData) % Update header with file info.
    end
 
  case {MMS_CONST.SDCProc.l2pre}
    % L2Pre process with L2A file as input
    if isempty(L2A_File)
      errStr = ['missing required input for ' procName ': L2A_File'];
      irf.log('critical',errStr)
      error('Matlab:MMS_SDC_SDP_PROC:Input', errStr)
    end

    irf.log('notice', [procName ' proc using: ' L2A_File]);
    src_fileData = load_file(L2A_File,'l2a');
    update_header(src_fileData) % Update header with file info.

  otherwise
    errStr = 'unrecognized procId';
    irf.log('critical', errStr); error(errStr)

end

% Write the output
filename_output = mms_sdp_cdfwrite(HdrInfo, Dmgr);

%% Write out filename as empty logfile so it can be easily found by SDC
% scripts.
if ~isempty(ENVIR.LOG_PATH_ROOT)
  unix(['touch', ' ', ENVIR.LOG_PATH_ROOT, filesep 'mms', ...
    HdrInfo.scIdStr, filesep, 'edp', filesep, filename_output, ...
    '_',runTime,'.log']);
end


%% Help functions
  function init_matlab_path()
    % Setup irfu-matlab and subdirs
    irfPath = [irf('path') filesep];
    irfDirectories = {'irf',...
      ['mission' filesep 'mms'],...
      ['mission' filesep 'cluster'],...
      ['contrib' filesep 'nasa_cdf_patch'],...
      };
    for iPath = 1:numel(irfDirectories)
      pathToAdd = [irfPath irfDirectories{iPath}];
      addpath(pathToAdd);
      irf.log('notice',['Added to path: ' pathToAdd]);
    end
  end

  function parse_input(procName, varargin)
    % Process input arguments
    if ~ischar(procName), error('MMS_SDC_SDP_PROC first argument must be a string.'); end
    [~,procId] = intersect( MMS_CONST.SDCProcs, lower(procName));
    if isempty(procId)
      error('MMS_SDC_SDP_PROC first argument must be one of: %s',...
        mms_constants2string('SDCProcs'));
    end
    procName = upper(procName);
    irf.log('notice', ['Starting process: ', procName]);

    %% Identify each input argument
    for j=1:nargin-1
      if isempty(varargin{j}), continue, end
      if(~ischar(varargin{j})), error('MMS_SDC_SDP_PROC input parameter must be string.'); end
      [pathIn, fileIn, extIn] = fileparts(varargin{j});
      if any([isempty(pathIn), isempty(fileIn), isempty(extIn)])
        error(['Expecting cdf file (full path), got: ', varargin{j}]);
      end
  
      if j==1,
        % Setup log and environment.
        HdrInfo.scIdStr = fileIn(4);
        ENVIR = mms_sdc_sdp_init(HdrInfo.scIdStr);
      elseif(~strcmp(HdrInfo.scIdStr, fileIn(4)))
        errStr = ['MMS_SDC_SDP_PROC called using MMS S/C: ', ...
          HdrInfo.scIdStr, ' and another file from MMS S/C: ', fileIn(4),'.'];
        irf.log('critical', errStr);
        irf.log('critical', ['Argument ', varargin{j}, ' did not match ',...
          'previous s/c ',varargin{j-1},'. Aborting with error.']);
        error(errStr);
      end

      if regexpi(fileIn,'_dce')
        % This argument is the dce file, (l1b raw, l2a/pre dce2d or similar)
        % Use this file to get TMmode directly from filename, and if comm.
        % data also sample rate. And also initialize the Dmgr.
        tmModeStr = fileIn(10:13); % mmsX_edp_[TMmode]_
        [~,tmMode] = intersect( MMS_CONST.TmModes, tmModeStr);
        if isempty(tmMode)
          errStr = ['Unrecognized tmMode (',tmModeStr,'), must be one of: '...
            mms_constants2string('TmModes')];
          irf.log('critical', errStr);  error(errStr);
        end
        if (tmMode==MMS_CONST.TmMode.comm)
          % Special case, Commissioning data, identify samplerate.
          irf.log('notice',...
            'Commissioning data, trying to identify samplerate from filename.');
          if regexpi(fileIn, '_dc[ev]8_') % _dcv8_ or _dce8_
            samplerate = MMS_CONST.Samplerate.comm_8;
          elseif regexpi(fileIn, '_dc[ev]32_') % _dcv32_ or _dce32_
            samplerate = MMS_CONST.Samplerate.comm_32;
          elseif regexpi(fileIn, '_dc[ev]64_') % _dcv64_ or _dce64_
            samplerate = MMS_CONST.Samplerate.comm_64;
          elseif regexpi(fileIn, '_dc[ev]128_') % _dcv128_ or _dce128_
            samplerate = MMS_CONST.Samplerate.comm_128;
          else
            % Possibly try to look at "dt" from Epoch inside of file? For
            % now just default to first TmMode (slow).
            irf.log('warning',...
              ['Unknown samplerate for Commissioning data from file: ',fileIn]);
            irf.log('warning', ['Defaulting samplerate to ',...
              MMS_CONST.Samplerate.(MMS_CONST.TmModes{1})]);
            samplerate = MMS_CONST.Samplerate.(MMS_CONST.TmModes{1});
          end
          Dmgr = mms_sdp_dmgr(str2double(HdrInfo.scIdStr), procId, tmMode, samplerate);
        else
          Dmgr = mms_sdp_dmgr(str2double(HdrInfo.scIdStr), procId, tmMode);
        end
      end

      if regexpi(fileIn, '_101_') % 101, mmsX_fields_hk_l1b_101_20150410_v0.0.1.cdf
        if ~isempty(HK_101_File)
          errStr = ['Multiple HK_101 files in input (',HK_101_File,' and ',varargin{j},')'];
          irf.log('critical', errStr);  error(errStr);
        end
        HK_101_File = varargin{j};
        irf.log('notice', ['HK_101 input file: ', HK_101_File]);
      elseif regexpi(fileIn, '_10e_') % 10E, mmsX_fields_hk_l1b_10e_20150410_v0.0.1.cdf
        if ~isempty(HK_10E_File)
          errStr = ['Multiple HK_10E files in input (',HK_10E_File,' and ',varargin{j},')'];
          irf.log('critical', errStr); error(errStr);
        end
        HK_10E_File = varargin{j};
        irf.log('notice', ['HK_10E input file: ', HK_10E_File]);
      elseif regexpi(fileIn, '_105_') % 105, mmsX_fields_hk_l1b_105_20150410_v0.0.1.cdf
        if ~isempty(HK_105_File)
          errStr = ['Multiple HK_105 files in input (',HK_10E_File,' and ',varargin{j},')'];
          irf.log('critical', errStr); error(errStr);
        end
        HK_105_File = varargin{j};
        irf.log('notice', ['HK_105 input file: ', HK_105_File]);
      elseif regexpi(fileIn, '_dcv\d{0,3}_') % _dcv_ or _dcv32_ or _dcv128_
        if ~isempty(DCV_File)
          errStr = ['Multiple DC V files in input (',DCV_File,' and ',varargin{j},')'];
          irf.log('critical', errStr); error(errStr);
        end
        DCV_File = varargin{j};
        irf.log('notice', ['DCV input file: ', DCV_File]);
      elseif regexpi(fileIn, '_dce\d{0,3}_') % _dce_ or _dce32_ or _dce128_
        if ~isempty(DCE_File)
          errStr = ['Multiple DC E files in input (',DCE_File,' and ',varargin{j},')'];
          irf.log('critical', errStr); error(errStr);
        end
        DCE_File = varargin{j};
        irf.log('notice', ['DCE input file: ', DCE_File]);
      elseif regexpi(fileIn, '_ace_') % _ace_
        if ~isempty(ACE_File)
          errStr = ['Multiple AC E files in input (',ACE_File,' and ',varargin{j},')'];
          irf.log('critical', errStr); error(errStr);
        end
        ACE_File = varargin{j};
        irf.log('notice', ['ACE input file: ', ACE_File]);
      elseif regexpi(fileIn, '_l2a_') % L2A file (produced by QL Fast/slow)
        if ~isempty(L2A_File)
          errStr = ['Multiple L2A files in input (',L2A_File,' and ',varargin{j},')'];
          irf.log('critical', errStr); error(errStr);
        end
        L2A_File = varargin{j};
      elseif regexpi(fileIn, '_DEFATT_') % DEFATT
        if ~isempty(DEFATT_File)
          errStr = ['Multiple DEFATT files in input (',DEFATT_File,' and ',varargin{j},')'];
          irf.log('critical', errStr); error(errStr);
        end
        DEFATT_File = varargin{j};
        irf.log('notice', ['DEFATT input file: ', DEFATT_File]);
      else
        % Unidentified input argument
        errStr = ['MMS_SDC_SDP_PROC unrecognized input file: ',varargin{j}];
        irf.log('critical', errStr); error(errStr);
      end
    end % End for j=1:nargin-1
  end % End parse_input

  function [filenameData] = load_file(fullFilename, dataType)
    [~, fileName, ~] = fileparts(fullFilename);
    filenameData = mms_fields_file_info(fileName);
    Dmgr.set_param(dataType, fullFilename);
  end


  function update_header(src)
    % Update header info
    if(regexpi(src.filename,'dce')), HdrInfo.startTime = src.startTime; end;
    % Initialization. Store startTime and first filename as parents_1.
    if(~isfield(HdrInfo,'parents_1'))
      HdrInfo.parents_1 = src.filename;
      HdrInfo.numberOfSources = 1;
    else % Next run.
      % Increase number of sources and new parent information.
      HdrInfo.numberOfSources = HdrInfo.numberOfSources + 1;
      HdrInfo.(sprintf('parents_%i', HdrInfo.numberOfSources)) = ...
        src.filename;
    end
  end

end
