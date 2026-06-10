using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SRJBackend.Infrastructure;
using SRJBackend.Infrastructure.Authorization;
using SRJBackend.Infrastructure.Extensions;
using SRJBackend.Infrastructure.Models;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://localhost:4000");

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddControllers();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddDbContext<SRJDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddAuthServices();
builder.Services.AddStudentServices();
builder.Services.AddAcademicServices();
builder.Services.AddEnrollmentServices();
builder.Services.AddSchoolFeeServices();
builder.Services.AddLookupServices();
builder.Services.AddPaymentServices();
builder.Services.AddAccountingServices();
builder.Services.AddStaffServices();
builder.Services.AddLunchServices();

builder.Services.AddScoped<IAuthorizationHandler, PermissionAuthorizationHandler>();
builder.Services.AddSingleton<IAuthorizationMiddlewareResultHandler, CustomAuthorizationMiddlewareResultHandler>();
builder.Services.AddAppAuthorization();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };
    });

var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .WithExposedHeaders("Content-Range"));
});

var app = builder.Build();

app.UseExceptionHandler();
app.UseCors("AllowFrontend");

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

/*
// Simple seed endpoint: POST /seed-user?email=x&password=y
app.MapPost("/seed-user", async (string email, string password, SRJDbContext db) =>
{
    var hashedPassword = Argon2.Hash(password);

    var user = new User
    {
        Email = email,
        HashedPassword = hashedPassword,
        Names = "Seed",
        PaternalLastname = "User",
        MaternalLastname = "Seed",
        Phone = "1234567890",
        IsActive = true
    };

    db.Users.Add(user);
    await db.SaveChangesAsync();

    return Results.Ok(new { message = "User created", email });
});
*/

app.Run();
