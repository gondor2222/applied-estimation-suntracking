% This function is the entrance point to the code. 
function runlocalization_MCL(inputfile)
    bound_t = [0 200];
    bound_l = [-pi/2 pi/2];
    [S, R, Q, Lambda_Psi] = init(bound_t, bound_l);
    state = [20 ; 45*pi/180]; %time, latitude in radians
    delta_t = 0.1;
    true_R = [5e-7 0; 0 1e-9]; %process noise covariance matrix
    true_Q = 1e-2; % measurement noise covariance matrix
    state_history = state;
    
    
    
    p2 = plot([0], [0]);
    hold on;
    p1 = plot(state_history(1,:), state_history(2,:)*180/pi);
    e1 = plot([0], [0]);
    e2 = plot([0], [0]);
    s = scatter(S(1,:), S(2,:) * 180/pi);
    legend('true sun height', 'true latitude', 'time of day error (0.1 hr)', ...
        'latitude error (0.1 deg)','candidates');
    ylim([-90 90]);
    hold off;
    for i = 1:3650*2
        
        height = observation_model([state ; 1]);
        if (height < 0)
            height = 0;
        end
        
        state(1) = state(1) + delta_t;
        state = state + mvnrnd([0 0], true_R)';
        if state(2) > pi/2
            state(2) = pi/2;
        end
        if state(2) < -pi/2
            state(2) = -pi/2;
        end
        state_history = [state_history state];
        [outlier, psi] = associate(S, height, 0.001, Q);
        if (height > 0)
            
            S_bar = weight(S, psi, outlier);
            S = systematic_resample(S_bar);
        end
        
        [maxval, maxind] = max(psi);
        
        mintimeerror = abs(mod(S(1,maxind) - state(1),1)) * 24;
        mintimeerror = mod(mintimeerror + 12, 24) - 12;
        mintimeerror = mintimeerror * 10;
        minlaterror  = abs(S(2,maxind) - state(2)) * 180/pi * 10;
        s.XData = S(1,:);
        s.YData = S(2,:) * 180/pi;
        p1.XData = state_history(1,:);
        p1.YData = state_history(2,:)*180/pi;
        p2.XData = [p2.XData state(1)];
        p2.YData = [p2.YData height*180/pi];
        e1.XData = [e1.XData state(1)];
        e1.YData = [e1.YData mintimeerror];
        e2.XData = [e2.XData state(1)];
        e2.YData = [e2.YData minlaterror];
        if mod(i, 10) == 0
            
            drawnow;
        end
        
        
        
        S = predict(S, R, delta_t);
        observation_model(S(:,5)) - height
    end
end
