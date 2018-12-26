% This function is the entrance point to the code. 
function runlocalization_MCL(inputfile)
    days_per_year = 365.2422;

    bound_t = [0 days_per_year];
    bound_l = [-pi/2 pi/2];
    [S, R, Q, Lambda_Psi] = init(bound_t, bound_l);
    state = [20 ; 45*pi/180]; %time, latitude in radians
    
    % Days per step
    delta_t = 0.1;
    
    % Standard deviation [minutes/step]
    time_process_noise = 1;
    
    % Standard deviation [radians/step]
    latitude_process_noise = 5 * 10^(-3);

    % Process noise covariance matrix
    true_R = [(time_process_noise/(60*24))^2 0; 0 latitude_process_noise^2];

    % Measurement noise covariance matrix
    true_Q = 1e-2;
    
    state_history = state;

    p2 = plot([0], [0], '.', 'DisplayName', 'True sun height');
    hold on;
    e1 = plot([0], [0], 'DisplayName', 'Time of day error (0.1 hr)');
    e2 = plot([0], [0], 'DisplayName', 'Latitude error (0.1 deg)');
    p1 = plot([0], [0], 'DisplayName', 'True latitude');
    s = scatter(S(1,:), S(2,:) * 180/pi, 'DisplayName', 'Candidates');
    bestEstimate = plot([0], [0], 'ro', 'DisplayName', 'Best Estimate');
    xlabel('Fractional Time');
    legend();
    ylim([-90 90]);
    xlim([0,730]);
    hold off;
    psi = zeros(1, size(S,2));
    for i = 1:3650*2
        s.XData = S(1,:);
        s.YData = S(2,:) * 180/pi;
        p1.XData = state_history(1,:);
        p1.YData = state_history(2,:)*180/pi;

        dt = delta_t * (0.8 + 0.2 * rand());
        % Update the time without noise
        state(1) = state(1) + dt;
        
        % Add some noise to the time and latitude update
        state = state + mvnrnd([0 0], true_R)';
        
        % Prevent the latitude from getting impossible values
        state(2) = max(min(state(2), pi/2), -pi/2);

        state_history = [state_history state];
        
        height = observation_model([state ; 1]);
        if (height < 0)
            height = 0;
        end
        
        % Update the states
        S = predict(S, R, dt);
        
        % Canonicalize particle states to remove symmetries
        % North/South hemisphere symmetry
        % we cannot differentiate between a state (t,lat) and the state (t+year/2,-lat)
        southern = S(2,:) < 0;
        S(1,southern) = S(1,southern) - days_per_year/2;
        S(2,southern) = -S(2,southern);
        % Note that the state is not perfectly periodic in a year because
        % a year does not have an integer number of days
        % S(1,:) = mod(S(1,:), days_per_year);
        
        if (height > 0)
            % Add in a few random particles
            [S2, R2, Q2, Lambda_Psi2] = init(bound_t, bound_l);
            S(:,randi(size(S,2), 10, 1)) = S2(:,1:10);

            [outlier, psi] = associate(S, height, 0.001, Q);
        end
        
        [maxval, maxind] = max(psi);
        
        G = S(1,:);
        H = round(S(2,:));
        I = mod(S(2,:), 1);
        estimated_state = [sum(psi .* G)/sum(psi); sum(psi .* H)/sum(psi); sum(psi .* I)/sum(psi)];
        estimated_state = [estimated_state(1), round(estimated_state(2)) + estimated_state(3)];
        estimated_state = S(:,maxind);
        mintimeerror = abs(mod(estimated_state(1) - state(1),1)) * 24;
        mintimeerror = mod(mintimeerror + 12, 24) - 12;
        mintimeerror = mintimeerror * 10;
        minlaterror  = abs(estimated_state(2) - state(2)) * 180/pi * 10;
        psi(maxind)
        
        % Plot the estimated state with all different symmetries and
        % periodicities.
        % The time is periodic in a year and there is a symmetry such that
        % we cannot differentiate between a state (t,lat) and the
        % state (t+year/2,-lat)
        bestEstimate.XData = [estimated_state(1), estimated_state(1) + days_per_year, estimated_state(1) - days_per_year];
        bestEstimate.XData = [bestEstimate.XData, bestEstimate.XData - days_per_year/2];
        bestEstimate.YData = [estimated_state(2) * 180/pi, estimated_state(2) * 180/pi, estimated_state(2) * 180/pi];
        bestEstimate.YData = [bestEstimate.YData, -bestEstimate.YData];
        
        % If we can see the sun, then add a new sample
        if (height > 0)
            S_bar = weight(S, psi, outlier);
            S = systematic_resample(S_bar);
        end

        p2.XData = [p2.XData state(1)];
        p2.YData = [p2.YData height*180/pi];
        e1.XData = [e1.XData state(1)];
        e1.YData = [e1.YData mintimeerror];
        e2.XData = [e2.XData state(1)];
        e2.YData = [e2.YData minlaterror];

        if mod(i, 10) == 0
            drawnow;
        end
        
        % observation_model(S(:,5)) - height
    end
end
