using SRJBackend.Application.Authorization;

namespace SRJBackend.Infrastructure.Authorization;

public static class AuthorizationPoliciesExtension
{
    public static IServiceCollection AddAppAuthorization(this IServiceCollection services)
    {
        services.AddAuthorization(options =>
        {
            options.AddPolicy("student.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("student.create")));
            options.AddPolicy("student.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("student.read")));
            options.AddPolicy("student.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("student.update")));
            options.AddPolicy("student.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("student.delete")));

            options.AddPolicy("institution.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("institution.create")));
            options.AddPolicy("institution.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("institution.read")));
            options.AddPolicy("institution.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("institution.update")));
            options.AddPolicy("institution.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("institution.delete")));

            options.AddPolicy("school-year.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-year.create")));
            options.AddPolicy("school-year.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-year.read")));
            options.AddPolicy("school-year.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-year.update")));
            options.AddPolicy("school-year.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-year.delete")));

            options.AddPolicy("grade.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade.create")));
            options.AddPolicy("grade.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade.read")));
            options.AddPolicy("grade.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade.update")));
            options.AddPolicy("grade.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade.delete")));

            options.AddPolicy("level.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("level.create")));
            options.AddPolicy("level.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("level.read")));
            options.AddPolicy("level.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("level.update")));
            options.AddPolicy("level.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("level.delete")));

            options.AddPolicy("shift.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("shift.read")));

            options.AddPolicy("grade-offering.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade-offering.create")));
            options.AddPolicy("grade-offering.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade-offering.read")));
            options.AddPolicy("grade-offering.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade-offering.update")));
            options.AddPolicy("grade-offering.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("grade-offering.delete")));

            options.AddPolicy("enrollment.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("enrollment.create")));
            options.AddPolicy("enrollment.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("enrollment.read")));

            options.AddPolicy("section.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("section.read")));

            options.AddPolicy("school-fee-concept.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-fee-concept.create")));
            options.AddPolicy("school-fee-concept.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-fee-concept.read")));
            options.AddPolicy("school-fee-concept.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-fee-concept.update")));
            options.AddPolicy("school-fee-concept.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("school-fee-concept.delete")));
        });

        return services;
    }
}
