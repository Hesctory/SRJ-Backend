using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class GradeOfferingShiftSection
{
    public int Id { get; set; }

    public int GradeOfferingShiftId { get; set; }

    public char? Section { get; set; }

    public short? SectionNumber { get; set; }

    public virtual ICollection<Enrollment> Enrollments { get; set; } = new List<Enrollment>();

    public virtual GradeOfferingShift GradeOfferingShift { get; set; } = null!;
}
