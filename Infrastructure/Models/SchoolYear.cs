using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class SchoolYear
{
    public int Id { get; set; }

    public short Year { get; set; }

    public DateOnly StartDate { get; set; }

    public DateOnly? EndDate { get; set; }

    public bool? IsActive { get; set; }

    public virtual ICollection<EnrollmentDebt> EnrollmentDebts { get; set; } = new List<EnrollmentDebt>();

    public virtual ICollection<Enrollment> Enrollments { get; set; } = new List<Enrollment>();

    public virtual ICollection<GradeOffering> GradeOfferings { get; set; } = new List<GradeOffering>();

    public virtual ICollection<SchoolFee> SchoolFees { get; set; } = new List<SchoolFee>();

    public virtual ICollection<SchoolYearMonth> SchoolYearMonths { get; set; } = new List<SchoolYearMonth>();
}
