using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class EmploymentContract
{
    public int Id { get; set; }

    public int StaffMemberId { get; set; }

    public int InstitutionId { get; set; }

    public int SchoolYearId { get; set; }

    public int JobPositionId { get; set; }

    public int? AreaId { get; set; }

    public DateOnly StartDate { get; set; }

    public DateOnly? EndDate { get; set; }

    public decimal? Salary { get; set; }

    public virtual WorkArea? Area { get; set; }

    public virtual Institution Institution { get; set; } = null!;

    public virtual JobPosition JobPosition { get; set; } = null!;

    public virtual SchoolYear SchoolYear { get; set; } = null!;

    public virtual StaffMember StaffMember { get; set; } = null!;
}
