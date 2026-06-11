using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Enrollment
{
    public int Id { get; set; }

    public string Code { get; set; } = null!;

    public int CodeNumber { get; set; }

    public int GradeOfferingShiftSectionId { get; set; }

    public int StudentId { get; set; }

    public int SchoolFeeConceptId { get; set; }

    public string? PreviousSchool { get; set; }

    public int SchoolYearId { get; set; }

    public DateOnly? EnrollmentDate { get; set; }

    public int StateId { get; set; }

    public bool Isnew { get; set; }

    public virtual EnrollmentDebt? EnrollmentDebt { get; set; }

    public virtual GradeOfferingShiftSection GradeOfferingShiftSection { get; set; } = null!;

    public virtual ICollection<LunchAssignment> LunchAssignments { get; set; } = new List<LunchAssignment>();

    public virtual SchoolFeeConcept SchoolFeeConcept { get; set; } = null!;

    public virtual SchoolYear SchoolYear { get; set; } = null!;

    public virtual EnrollmentState State { get; set; } = null!;

    public virtual Student Student { get; set; } = null!;
}
