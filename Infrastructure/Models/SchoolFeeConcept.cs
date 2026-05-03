using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class SchoolFeeConcept
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<Enrollment> Enrollments { get; set; } = new List<Enrollment>();

    public virtual ICollection<SchoolFee> SchoolFees { get; set; } = new List<SchoolFee>();
}
