function parameters = load_parameters(varargin)
    parameters = yaml.loadFile('configs/default_config.yaml', "ConvertToArray", true);
    
    if nargin == 1
        extra_config_file = varargin{1};
        extra_parameters = yaml.loadFile(fullfile('configs',extra_config_file), "ConvertToArray", true);
        %assert(extra_parameters.transducer.source_freq_hz == parameters.default_freq || isfield(extra_parameters,'medium'), 'The transducer frequency does not match the frequency used for the medium parameters in the default config file. Provide medium parameters in your config.')
        
%         if (extra_parameters.transducer.source_freq_hz ~= parameters.default_freq) && ~isfield(extra_parameters,'medium')
%             warning('The transducer frequency does not match the frequency used for the medium parameters in the default config file. Recalculating aMake sure that the medium parameters in your config file account for the correct frequency.')
%             
%         end
            
        parameters = MergeStruct(parameters, extra_parameters);
    end

    assert(parameters.interactive==0 || usejava('desktop'), 'Matlab should run in desktop mode if parameters.interactive is enabled in tuSIM config');

    if isfield(parameters, 'transducer')
        if ~isfield(parameters.transducer,'source_phase_rad')
            assert(isfield(parameters.transducer,'source_phase_deg'), 'Source phase should be set in transducer parameters as source_phase_rad or source_phase_deg')
            parameters.transducer.source_phase_rad = parameters.transducer.source_phase_deg/180*pi;
        end
        if ~isfield(parameters.transducer,'dist_to_plane_mm')
            parameters.transducer.dist_to_plane_mm = sqrt(parameters.transducer.curv_radius_mm^2-(max(parameters.transducer.Elements_OD_mm)/2)^2);
            fprintf('Distance to transducer plane is not provided, calculated based on curvature radius and parameters.transducer diameter as %.2f mm\n', parameters.transducer.dist_to_plane_mm)
        end

        if length(parameters.transducer.source_amp)==1 && parameters.transducer.n_elements > 1
            parameters.transducer.source_amp = repmat(parameters.transducer.source_amp, [1 parameters.transducer.n_elements]);
        end
        if iscell(parameters.transducer.source_phase_rad)
            for i = 1:length(parameters.transducer.source_phase_rad)
                if ~isnumeric(parameters.transducer.source_phase_rad{i})
                    parameters.transducer.source_phase_rad{i}= eval(parameters.transducer.source_phase_rad{i});
                end
            end
            parameters.transducer.source_phase_rad = cell2mat(parameters.transducer.source_phase_rad);
            
        end
        
        if ~isfield(parameters.transducer,'source_phase_deg')
            parameters.transducer.source_phase_deg = parameters.transducer.source_phase_rad/pi*180;
        end
    elseif nargin == 1
        assert(all(confirmation_dlg('The transducer info is missing in the configuration file, do you want to continue?','Yes','No')), 'Exiting');
    end
    

    parameters.grid_step_m = parameters.grid_step_mm/1e3; % [meters]
    if ~isfield(parameters, 'n_sim_dims')
        if isfield(parameters,'default_grid_dims')
            parameters.n_sim_dims = length(parameters.default_grid_dims);
        else
            parameters.n_sim_dims = 3;
        end            
    end
    
    if ~isfield(parameters,'default_grid_dims')
        parameters.default_grid_dims = repmat(parameters.default_grid_size, [1 parameters.n_sim_dims]);
    end
    if parameters.run_heating_sims
        check_thermal_parameters(parameters);
    end
    %% Output parameters checks

    % Sanitize output file affix
    sanitized_affix = regexprep(parameters.results_filename_affix,'[^a-zA-Z0-9_]','_');
    if ~strcmp(sanitized_affix, parameters.results_filename_affix)
        fprintf('The original `results_filename_affix` was sanitized, "%s" will be used instead of "%s"\n', sanitized_affix, parameters.results_filename_affix)
        parameters.results_filename_affix = sanitized_affix;
    end

    % Set output directory
    if isfield(parameters,'output_location')
        javaFileObj = java.io.File(parameters.output_location); % check if the path is absolute
        if javaFileObj.isAbsolute()
            parameters.output_dir = fullfile(parameters.output_location);
        else
            parameters.output_dir = fullfile(parameters.data_path, parameters.output_location);
        end
    else
        parameters.output_dir = fullfile(parameters.data_path, 'sim_outputs/');
    end
 
    if isfield(parameters, 'ld_library_path') && parameters.ld_library_path ~= ""
        assert(exist(parameters.ld_library_path, 'dir'), 'The path in parameters.ld_library_path does not exist')
    end
    
    assert(exist(fullfile(parameters.simnibs_bin_path, parameters.segmentation_software), 'file'), sprintf('The path segmentation software (%s) does not exist at %s.', parameters.segmentation_software, parameters.simnibs_bin_path))
     
    % set segmentation path to data_path if no specific seg_path is defined
    if ~isfield(parameters, 'seg_path') || parameters.seg_path == ""
        parameters.seg_path = parameters.data_path;
    end

end