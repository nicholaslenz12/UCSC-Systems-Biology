%% PLOT_SIMULATION

%% ------------------------------------------------------------------------
% MODEL SELECTION
% -------------------------------------------------------------------------
addpath('../Models')
model = 'model_3';
func = str2func(model);

%% ------------------------------------------------------------------------
% INITIAL CONDITIONS
% -------------------------------------------------------------------------
WT_0 = 100;
C_0  = 50;
A_0 = 0;
M_0 = 0;

%% ------------------------------------------------------------------------
% SIMULATION PARAMETERS
% -------------------------------------------------------------------------
lookahead = 20;
recessionLength = 10;
step_count = 200;
endSimulation  = 10000;
ratio = recessionLength/lookahead;
new_index = cast(step_count*ratio, 'int32');
threshold = 20;
distances = threshold + .01;

%% ------------------------------------------------------------------------
% INITIALIZATION
% -------------------------------------------------------------------------
start_time = 0;
scenario_count = [3 1];
x = [];
solutions = [];
WT_ref = 2*WT_0;

if ~strcmp(model, 'model_1') && ~strcmp(model, 'model_2') && ~strcmp(model, 'model_3')
    ME = MException('MyComponent:noSuchVariable','Model: %s does not exist',model);
    throw(ME)
end

if strcmp(model, 'model_1') || strcmp(model, 'model_2')
    for idx=1:scenario_count
        x = [x;WT_0, C_0, A_0, idx];
        solutions = [start_time, WT_0, C_0, A_0, 1, WT_ref];
    end
else
    for idx=1:scenario_count
        x = [x;WT_0, C_0, A_0, M_0, idx];
        solutions = [start_time, WT_0, C_0, A_0, M_0, 1, WT_ref];
    end
end

%% ------------------------------------------------------------------------
% LOOP
% -------------------------------------------------------------------------
iteration = 0;

while iteration < endSimulation/recessionLength

    % Generates the each timestep in the iteration.
    end_time = start_time + lookahead;
    tspan=start_time:lookahead/step_count:end_time;

    % Sets the reference for each time in the time span.
    WT_ref_vec = WT_ref.*ones(size(tspan)).';

    % Predict the system for each value of the controller state.
    predicted_solutions = mpc(x, tspan, func);

    % Detemine which value of the controller minimizes the error of Pwt wrt
    % the reference.
    distances = zeros(scenario_count);
    for idx=1:scenario_count
        distances(idx) = (sum((predicted_solutions(:,1,idx)-WT_ref_vec).^2))^(1/2);
    end
    [min_distance, min_idx] = min(distances);

    % Initialization for next recession.
    for idx=1:scenario_count
        x(idx,:) = [predicted_solutions(new_index+1,1:end-1,min_idx) idx];
    end

    % Record best solution.
    solutions = [solutions; ...
                tspan(2:new_index+1).', ...
                predicted_solutions(2:new_index+1,:,min_idx), ...
                WT_ref_vec(2:new_index+1)];

    % Record minimum distance.
    distances = [distances; min_distance];

    start_time = start_time + recessionLength;
    iteration = iteration + 1;
end

%% ------------------------------------------------------------------------
% PLOT SOLUTIONS
% -------------------------------------------------------------------------
master_xlim = [0 endSimulation];
figure('Renderer', 'painters', 'Position', [720 450 600 400])

%% ------------------------------------------------------------------------
% POPULATION SIZE PLOT
% -------------------------------------------------------------------------
subplot(2,3,[1 2 4 5])
if strcmp(model, 'model_3')
    plot(solutions(:,1),(solutions(:,7)),'LineWidth',1,'Color',[0 1 0])
    hold on
    plot(solutions(:,1),(solutions(:,5)),'LineWidth',1,'Color',[0 0.5 1])
    hold on
else
    plot(solutions(:,1),(solutions(:,6)),'LineWidth',1,'Color',[0 1 0])
    hold on
end
plot(solutions(:,1),(solutions(:,2)),'LineWidth',1,'Color',[1 0 0])
hold on
plot(solutions(:,1),(solutions(:,3)),'LineWidth',1,'Color',[0 0 1])
hold on
if strcmp(model, 'model_3')
    legend('Target Pop.', 'Metabolite', 'Invasive Pop.', 'Controller Pop.')
else
    legend('Target Pop.', 'Invasive Pop.', 'Controller Pop.')
end
xlim(master_xlim)
ylim([0 inf])
grid on
xlabel('Time')
ylabel('Population Size')
title('Bacteria Populations')

%% ------------------------------------------------------------------------
% ANTIBIOTIC CONCENTRATION PLOT
% -------------------------------------------------------------------------
subplot(2,3,3)
plot(solutions(:,1),(solutions(:,4)),'LineWidth',1,'Color',[1 0.5 0])
hold on
xlim(master_xlim)
grid on
xlabel('Time')
ylabel('Concentration')
title('Antibiotic Concentration')

%% ------------------------------------------------------------------------
% SWITCH STATE PLOT
% -------------------------------------------------------------------------
subplot(2,3,6)
if strcmp(model, 'model_3')
    switch_state = area(solutions(:,1),(solutions(:,6)-1)/2);
else
    switch_state = area(solutions(:,1),(solutions(:,5)-1)/2);
end
set(switch_state,'facealpha',.5)
xlim(master_xlim)
grid on
xlabel('Time')
ylabel('On / Off')
title('Switch State')

%% ------------------------------------------------------------------------
% SAVE FIGURE
% -------------------------------------------------------------------------
filename = model;
iterator = 1;

% Incremental file-naming
while isfile(strcat(filename,'.pdf'))
    filename = strcat(filename, '_', num2str(iterator));
    iterator = iterator + 1;
end
print('-bestfit',filename,'-dpdf')

%% ------------------------------------------------------------------------
% FUNCTIONS
% -------------------------------------------------------------------------
function solutions = mpc(x, tspan, fun)
    solutions = [];
    for idx=1:size(x,1)
        solutions = cat(3,solutions,fun(x(idx,:), tspan));
    end
end