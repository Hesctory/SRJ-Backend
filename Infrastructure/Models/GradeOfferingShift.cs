using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class GradeOfferingShift
{
    public int Id { get; set; }

    public int GradeOfferingId { get; set; }

    public short? Sections { get; set; }

    public int ShiftId { get; set; }

    public virtual GradeOffering GradeOffering { get; set; } = null!;

    public virtual ICollection<GradeOfferingShiftSection> GradeOfferingShiftSections { get; set; } = new List<GradeOfferingShiftSection>();

    public virtual Shift Shift { get; set; } = null!;
}
