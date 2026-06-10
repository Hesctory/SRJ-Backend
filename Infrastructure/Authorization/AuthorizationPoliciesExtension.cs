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
            options.AddPolicy("enrollment.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("enrollment.update")));
            options.AddPolicy("enrollment.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("enrollment.delete")));

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

            options.AddPolicy("enrollment-debt.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("enrollment-debt.read")));

            options.AddPolicy("debt-installment.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("debt-installment.read")));

            options.AddPolicy("payment-method.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("payment-method.read")));

            options.AddPolicy("payment.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("payment.create")));

            options.AddPolicy("accounting-plan.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("accounting-plan.create")));
            options.AddPolicy("accounting-plan.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("accounting-plan.read")));
            options.AddPolicy("accounting-plan.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("accounting-plan.update")));
            options.AddPolicy("accounting-plan.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("accounting-plan.delete")));

            options.AddPolicy("work-area.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("work-area.create")));
            options.AddPolicy("work-area.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("work-area.read")));
            options.AddPolicy("work-area.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("work-area.update")));
            options.AddPolicy("work-area.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("work-area.delete")));

            options.AddPolicy("job-position.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("job-position.create")));
            options.AddPolicy("job-position.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("job-position.read")));
            options.AddPolicy("job-position.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("job-position.update")));
            options.AddPolicy("job-position.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("job-position.delete")));

            options.AddPolicy("staff-member.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("staff-member.create")));
            options.AddPolicy("staff-member.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("staff-member.read")));
            options.AddPolicy("staff-member.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("staff-member.update")));
            options.AddPolicy("staff-member.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("staff-member.delete"))); 

            options.AddPolicy("employment-contract.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("employment-contract.create")));
            options.AddPolicy("employment-contract.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("employment-contract.read")));
            options.AddPolicy("employment-contract.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("employment-contract.update")));
            options.AddPolicy("employment-contract.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("employment-contract.delete")));

            options.AddPolicy("lunch-category.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch-category.create")));
            options.AddPolicy("lunch-category.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch-category.read")));
            options.AddPolicy("lunch-category.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch-category.update")));
            options.AddPolicy("lunch-category.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch-category.delete")));

            options.AddPolicy("lunch.create", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch.create")));
            options.AddPolicy("lunch.read", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch.read")));
            options.AddPolicy("lunch.update", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch.update")));
            options.AddPolicy("lunch.delete", policy =>
                policy.Requirements.Add(new PermissionRequirement("lunch.delete")));
        });

        return services;
    }
}
