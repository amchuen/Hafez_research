function OUT = dufortFrankel(GR, FL, BC, func, epsFunc, U0)

%% Run Checks

% Check if it is fixed time-sim or run until steady state

% Check if cylindrical or cartesian coordinates
% if GR.isPolar
%     % Raidus Averagess
%     GR.RR_N = [0.5.*(GR.RR(2:end,:) + GR.RR(1:(end-1),:)); 0.5.*((GR.RR(end,:)+GR.dr) + GR.RR(end,:))];
%     GR.RR_S = 0.5.*([2.*GR.RR(1,:)-GR.dr; GR.RR(2:end,:) + GR.RR(1:(end-1),:)]);
% end

%% Initialize Variables

% Matrix Dimensions
% 1:Y, 2:X, 3:vec, 4:t
UU = struct('fv',repmat(U0,1,1,1,3),'f2',zeros(size(U0)), 'f1', zeros(size(U0)));

% Calculate Residual before running simulation
res = [1, 1; 1,1]; %resCalc(GR, FL, BC, func, epsFunc, UU.fv(:,:,:,end));
time = [-GR.dt, 0];

%% Run Simulation

while norm(res(end,:)) > GR.tol || time(end) < GR.tEnd
    
    % Step-Forward
    UU.fv(:,:,:,1:2) = UU.fv(:,:,:,2:3);
    
    % Define stability coefficients
    if GR.isPolar
        alpha2 = 2.*GR.dt.*epsFunc(GR,BC,'T')./(GR.RR.*GR.dT).^2;
        alpha1 = 2.*GR.dt.*epsFunc(GR,BC,'R')./(GR.RR.*GR.dR.^2).*0.5.*(GR.RR_N+GR.RR_S);
    else
        alpha2 = 2.*GR.dt.*epsFunc(GR, BC, 'X')./(GR.dx.^2);
        alpha1 = 2.*GR.dt.*epsFunc(GR, BC, 'Y')./(GR.dy.^2);
    end
    alphaTot = alpha2 + alpha1;
    
    % Calculate non-diffusive terms
    [funcOut, waveSpd] = func(GR, FL, BC, UU.fv(:,:,:,2));
    alphaWave = 2.*(waveSpd(1)./(2.*epsFunc(GR, BC, 'X')) + waveSpd(2)./(2.*epsFunc(GR,BC,'Y')))*GR.dt;
%     alphaWave = sqrt(waveSpd(1)^2 + waveSpd(2)^2).*GR.dt./(epsFunc(GR, BC, 'X'));% (max(abs(Ur(:))) + max(abs(VT(:))))*dt./eps_s;
%     alphaWave = (waveSpd(1)+ waveSpd(2)).*GR.dt;
    
    % Check CFL
    cflFactor = 1;
    if (max(abs(alphaWave(:))) ~= GR.CFL) || (max(abs(alphaTot(:))) > GR.CFL) %-> DF method might allow for unconditional stability for pure diffusion
        %cflFactor = GR.CFL./max(alphaTot(:));
        cflFactor = min(GR.CFL./max(abs(alphaWave(:))), GR.CFL./max(abs(alphaTot(:))));
        alpha2 = alpha2 .* (1+cflFactor)./2;
        alpha1 = alpha1 .* (1+cflFactor)./2;
        GR.dt = GR.dt .* cflFactor;
        
        if abs(log10(cflFactor)) > 0.005
            fprintf('CFL condition not met!\n');
            fprintf('Changing time steps!\n');
            fprintf('New time step:%0.5e\n', GR.dt);
        end
    end
    
    % Compute Center-Spacing Derivatives
    UU.f2(:,2:end-1,:) = UU.fv(:,3:end,:,2) + UU.fv(:,1:end-2,:,2);
    UU.f2(:,1,:) = UU.fv(:,2,:,2) + bcCalc(GR, BC, UU.fv(:,:,:,2), 'W');
    UU.f2(:,end,:) = UU.fv(:,end-1,:,2) + bcCalc(GR, BC, UU.fv(:,:,:,2), 'E');
    if GR.isPolar
        UU.f1(2:end-1,:,:) = GR.RR_N(2:end-1,:).*UU.fv(3:end,:,:,2) + GR.RR_S(2:end-1,:).*UU.fv(1:end-2,:,:,2);
        UU.f1(1,:,:) = GR.RR_N(1,:).*UU.fv(2,:,:,2) + GR.RR_S(1,:).*bcCalc(GR, BC, UU.fv(:,:,:,2),'S');
        UU.f1(end,:,:) = GR.RR_S(end,:).*UU.fv(end-1,:,:,2) + GR.RR_N(end,:).*bcCalc(GR,BC, UU.fv(:,:,:,2),'N');
        
        % Compute Time-step
        UU.fv(:,:,:,3) = ((1-alpha2-alpha1).*UU.fv(:,:,:,1)+alpha2.*(UU.f2)+alpha1.*(UU.f1)./(0.5.*(GR.RR_N+GR.RR_S))-(1+1/cflFactor).*GR.dt.*funcOut)./(1+alpha2+alpha1);
    else
        UU.f1(2:end-1,:,:) = UU.fv(3:end,:,:,2) + UU.fv(1:end-2,:,:,2);
        UU.f1(1,:,:) = UU.fv(2,:,:,2) + bcCalc(GR, BC, UU.fv(:,:,:,2),'S');
        UU.f1(end,:,:) = UU.fv(end-1,:,:,2) + bcCalc(GR,BC, UU.fv(:,:,:,2),'N');
        
        % Compute Time-step
        UU.fv(:,:,:,3) = ((1-alpha2-alpha1).*UU.fv(:,:,:,1)+alpha2.*(UU.f2)+alpha1.*(UU.f1)-(1+1/cflFactor).*GR.dt.*funcOut)./(1+alpha2+alpha1);
    end
    
    % Calculate Residual
    res(end+1,:) = resCalc(GR, UU.fv(:,:,:,end-1:end));    
    time(end+1) = time(end) + GR.dt;
    
    % Run Additional Time-Stepping Checks
    if any(any(UU.fv(:,:,1,end)<=0))
        fprintf('Check Rho!\n');
    end
    
    if (~isreal(UU.fv(:,:,:,end)) || any(any(any(isnan(UU.fv(:,:,:,end))))))
        error('Solution exhibits non-solutions (either non-real or NaN) in nodes!\n');
%         break;
    end
    
    if ~isreal(UU.fv(:,:,:,end))
       fprintf('Check phi!\n'); 
    end
    
    if (length(res) >= 500) && (mod(length(res), 500) == 0)
        fprintf('Iteration Ct: %i\n', length(res));
        fprintf('Current Residual: %0.5e\n', max(res(end,:)));
    end
    
    figure(1);
    semilogy(time, res(:,1));
    hold on; semilogy(time, res(:,2));
    legend('\rho', '\phi', 'Location', 'Best');
    %contourf(GR.XX, GR.YY, UU.fv(:,:,1,end),50);
    title(['t = ' num2str(time(end))]);
    hold off;
    %colorbar;
    drawnow;
    
end


%% Output for Post-Processing
OUT.Uvals = UU.fv;
OUT.time = time;
OUT.res = res;

end

function res = resCalc(GR, Uvals) 

% checks steady state by calculateing Ut?
for i = 1:size(Uvals,3)
    tempres = abs(Uvals(:,:,i,end) - Uvals(:,:,i,end-1))./GR.dt;
%     tempres = abs(Uvals(:,:,i,end)./Uvals(:,:,i,end-1));%./GR.dt;
    res(i) = max(tempres(:));
end

end