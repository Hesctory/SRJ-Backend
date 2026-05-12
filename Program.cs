using System.Text;
using Isopoh.Cryptography.Argon2;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SRJBackend.Application.Interfaces;
using SRJBackend.Application.UseCases;
using SRJBackend.Infrastructure;
using SRJBackend.Infrastructure.Authorization;
using SRJBackend.Infrastructure.Models;
using SRJBackend.Infrastructure.Repositories;
using SRJBackend.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://localhost:4000");

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddControllers();

builder.Services.AddDbContext<SRJDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<IAuthRepository, AuthRepository>();
builder.Services.AddScoped<IPersonRepository, PersonRepository>();
builder.Services.AddScoped<IEducationalPersonRepository, EducationalPersonRepository>();
builder.Services.AddScoped<IStudentRepository, StudentRepository>();
builder.Services.AddScoped<IStudentHomeRepository, StudentHomeRepository>();
builder.Services.AddScoped<IFamiliarStudentRelationshipRepository, FamiliarStudentRelationshipRepository>();
builder.Services.AddScoped<IGenderRepository, GenderRepository>();
builder.Services.AddScoped<IDocumentTypeRepository, DocumentTypeRepository>();
builder.Services.AddScoped<IEthnicSelfIdentificationRepository, EthnicSelfIdentificationRepository>();
builder.Services.AddScoped<IDepartmentRepository, DepartmentRepository>();
builder.Services.AddScoped<IProvinceRepository, ProvinceRepository>();
builder.Services.AddScoped<IDistrictRepository, DistrictRepository>();
builder.Services.AddScoped<ILanguageRepository, LanguageRepository>();
builder.Services.AddScoped<IDisabilityTypeRepository, DisabilityTypeRepository>();
builder.Services.AddScoped<IDisabilityDegreeRepository, DisabilityDegreeRepository>();
builder.Services.AddScoped<IFamiliarRelationshipTypeRepository, FamiliarRelationshipTypeRepository>();
builder.Services.AddScoped<IFamiliarRepository, FamiliarRepository>();
builder.Services.AddScoped<IChildbirthTypeRepository, ChildbirthTypeRepository>();
builder.Services.AddScoped<ICivilStateRepository, CivilStateRepository>();
builder.Services.AddScoped<ILevelOfEducationRepository, LevelOfEducationRepository>();
builder.Services.AddScoped<IReligionRepository, ReligionRepository>();
builder.Services.AddScoped<IRucStateRepository, RucStateRepository>();
builder.Services.AddScoped<IInstitutionRepository, InstitutionRepository>();
builder.Services.AddScoped<ISchoolYearRepository, SchoolYearRepository>();
builder.Services.AddScoped<IGradeRepository, GradeRepository>();
builder.Services.AddScoped<ILevelRepository, LevelRepository>();
builder.Services.AddScoped<IShiftRepository, ShiftRepository>();
builder.Services.AddScoped<IGradeOfferingRepository, GradeOfferingRepository>();
builder.Services.AddScoped<IGradeOfferingShiftSectionRepository, GradeOfferingShiftSectionRepository>();
builder.Services.AddScoped<IEnrollmentRepository, EnrollmentRepository>();
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<LoginUseCase>();
builder.Services.AddScoped<CreateStudentUseCase>();
builder.Services.AddScoped<UpdateStudentUseCase>();
builder.Services.AddScoped<DeleteStudentUseCase>();
builder.Services.AddScoped<GetStudentsUseCase>();
builder.Services.AddScoped<GetStudentByIdUseCase>();
builder.Services.AddScoped<GetGendersUseCase>();
builder.Services.AddScoped<GetDocumentTypesUseCase>();
builder.Services.AddScoped<GetEthnicSelfIdentificationsUseCase>();
builder.Services.AddScoped<GetDepartmentsUseCase>();
builder.Services.AddScoped<GetProvincesUseCase>();
builder.Services.AddScoped<GetDistrictsUseCase>();
builder.Services.AddScoped<GetLanguagesUseCase>();
builder.Services.AddScoped<GetDisabilityTypesUseCase>();
builder.Services.AddScoped<GetDisabilityDegreesUseCase>();
builder.Services.AddScoped<GetFamiliarRelationshipTypesUseCase>();
builder.Services.AddScoped<GetChildbirthTypesUseCase>();
builder.Services.AddScoped<GetCivilStatesUseCase>();
builder.Services.AddScoped<GetLevelOfEducationsUseCase>();
builder.Services.AddScoped<GetReligionsUseCase>();
builder.Services.AddScoped<GetRucStatesUseCase>();
builder.Services.AddScoped<GetInstitutionsUseCase>();
builder.Services.AddScoped<GetInstitutionByIdUseCase>();
builder.Services.AddScoped<CreateInstitutionUseCase>();
builder.Services.AddScoped<UpdateInstitutionUseCase>();
builder.Services.AddScoped<DeleteInstitutionUseCase>();
builder.Services.AddScoped<GetSchoolYearsUseCase>();
builder.Services.AddScoped<GetSchoolYearByIdUseCase>();
builder.Services.AddScoped<CreateSchoolYearUseCase>();
builder.Services.AddScoped<UpdateSchoolYearUseCase>();
builder.Services.AddScoped<DeleteSchoolYearUseCase>();
builder.Services.AddScoped<GetGradesUseCase>();
builder.Services.AddScoped<GetGradeByIdUseCase>();
builder.Services.AddScoped<CreateGradeUseCase>();
builder.Services.AddScoped<UpdateGradeUseCase>();
builder.Services.AddScoped<DeleteGradeUseCase>();
builder.Services.AddScoped<GetLevelsUseCase>();
builder.Services.AddScoped<GetLevelByIdUseCase>();
builder.Services.AddScoped<CreateLevelUseCase>();
builder.Services.AddScoped<UpdateLevelUseCase>();
builder.Services.AddScoped<DeleteLevelUseCase>();
builder.Services.AddScoped<GetShiftsUseCase>();
builder.Services.AddScoped<GetShiftByIdUseCase>();
builder.Services.AddScoped<GetGradeOfferingsUseCase>();
builder.Services.AddScoped<GetGradeOfferingByIdUseCase>();
builder.Services.AddScoped<CreateGradeOfferingUseCase>();
builder.Services.AddScoped<UpdateGradeOfferingUseCase>();
builder.Services.AddScoped<DeleteGradeOfferingUseCase>();
builder.Services.AddScoped<GetSectionsUseCase>();
builder.Services.AddScoped<GetEnrollmentsByStudentUseCase>();
builder.Services.AddScoped<GetLatestEnrollmentByStudentUseCase>();
builder.Services.AddScoped<CreateEnrollmentUseCase>();
builder.Services.AddScoped<ISchoolFeeConceptRepository, SchoolFeeConceptRepository>();
builder.Services.AddScoped<GetSchoolFeeConceptsUseCase>();
builder.Services.AddScoped<GetSchoolFeeConceptByIdUseCase>();
builder.Services.AddScoped<CreateSchoolFeeConceptUseCase>();
builder.Services.AddScoped<UpdateSchoolFeeConceptUseCase>();
builder.Services.AddScoped<DeleteSchoolFeeConceptUseCase>();

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

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend",
        policy =>
        {
            policy.WithOrigins("http://localhost:5173") // o el puerto de tu frontend
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .WithExposedHeaders("Content-Range");
        });
});

var app = builder.Build();

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
