using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Shift
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<GradeOfferingShift> GradeOfferingShifts { get; set; } = new List<GradeOfferingShift>();

    public virtual ICollection<LunchAssignment> LunchAssignments { get; set; } = new List<LunchAssignment>();

    public virtual ICollection<SchoolFee> SchoolFees { get; set; } = new List<SchoolFee>();
}
