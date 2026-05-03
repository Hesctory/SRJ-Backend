using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class GradeOffering
{
    public int Id { get; set; }

    public int GradeId { get; set; }

    public int SchoolYearId { get; set; }

    public virtual Grade Grade { get; set; } = null!;

    public virtual ICollection<GradeOfferingShift> GradeOfferingShifts { get; set; } = new List<GradeOfferingShift>();

    public virtual SchoolYear SchoolYear { get; set; } = null!;
}
