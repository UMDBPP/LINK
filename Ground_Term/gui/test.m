target = [-0.85;0.53;0];
target = target ./norm(target)

normal = [0;1;0];
normal = normal ./norm(normal)

% syms Tx Ty Tz
% syms Nx Ny Nz
% target = [Tx; Ty; Tz];
% normal = [Nx; Ny; Nz];
% syms Tx Ty Tz
% syms Nx Ny Nz
% 
% target = [Tx;Ty;Tz];
% normal = [Nx;Ny;Nz];

% inplanetgt = cross(normal,cross(target,normal))
% inplanetgt = inplanetgt ./norm(inplanetgt);

inplanetgt = [1-normal(1)^2, -normal(1)*normal(2), -normal(1)*normal(3);...
    -normal(2)*normal(1), 1-normal(2)^2, normal(2)*normal(3);...
    -normal(3)*normal(1), -normal(3)*normal(2), 1-normal(3)^2]*target

el_ang =  acos(dot(inplanetgt,[1;0;0]))*180/pi;

if(inplanetgt(3)>0)
    -el_ang
else
    el_ang
end

close all
plot3([0 1],[0 0],[0 0],'r')
hold on
plot3([0 0],[0 1],[0 0],'g')
plot3([0 0],[0 0],[0 1],'b')

plot3([0 target(1)],[0 target(2)],[0 target(3)])
grid on
% set(gca,'Ydir','reverse')
set(gca,'Zdir','reverse')